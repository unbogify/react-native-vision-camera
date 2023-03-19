//
//  CameraView+RecordVideo.swift
//  mrousavy
//
//  Created by Marc Rousavy on 16.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import AVFoundation

// MARK: - CameraView + AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate

extension CameraView: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
  /**
   Starts a video + audio recording with a custom Asset Writer.
   */
  func startRecording(options: NSDictionary, callback jsCallbackFunc: @escaping RCTResponseSenderBlock) {
    cameraQueue.async {
      ReactLogger.log(level: .info, message: "Starting Video recording...")
      let callback = Callback(jsCallbackFunc)

      var fileType = AVFileType.mov
      if let fileTypeOption = options["fileType"] as? String {
        guard let parsed = try? AVFileType(withString: fileTypeOption) else {
          callback.reject(error: .parameter(.invalid(unionName: "fileType", receivedValue: fileTypeOption)))
          return
        }
        fileType = parsed
      }

      let errorPointer = ErrorPointer(nilLiteral: ())
      let fileExtension = fileType.descriptor ?? "mov"
      guard let tempFilePath = RCTTempFilePath(fileExtension, errorPointer) else {
        callback.reject(error: .capture(.createTempFileError), cause: errorPointer?.pointee)
        return
      }

      ReactLogger.log(level: .info, message: "File path: \(tempFilePath)")
      let tempURL = URL(string: "file://\(tempFilePath)")!

      if let flashMode = options["flash"] as? String {
        // use the torch as the video's flash
        self.setTorchMode(flashMode)
      }

      guard let videoOutput = self.videoOutput else {
        if self.video?.boolValue == true {
          callback.reject(error: .session(.cameraNotReady))
          return
        } else {
          callback.reject(error: .capture(.videoNotEnabled))
          return
        }
      }
      guard let videoInput = self.videoDeviceInput else {
        callback.reject(error: .session(.cameraNotReady))
        return
      }

      // TODO: The startRecording() func cannot be async because RN doesn't allow
      //       both a callback and a Promise in a single function. Wait for TurboModules?
      //       This means that any errors that occur in this function have to be delegated through
      //       the callback, but I'd prefer for them to throw for the original function instead.

      let enableAudio = self.audio?.boolValue == true

      let onFinish = { (recordingSession: RecordingSession, status: AVAssetWriter.Status, error: Error?) in
        defer {
          if enableAudio {
            self.audioQueue.async {
              self.deactivateAudioSession()
            }
          }
          if options["flash"] != nil {
            // Set torch mode back to what it was before if we used it for the video flash.
            self.setTorchMode(self.torch)
          }
        }

        self.recordingSession = nil
        self.isRecording = false
        ReactLogger.log(level: .info, message: "RecordingSession finished with status \(status.descriptor).")

        if let error = error as NSError? {
          if error.domain == "capture/aborted" {
            callback.reject(error: .capture(.aborted), cause: error)
          } else {
            callback.reject(error: .capture(.unknown(message: "An unknown recording error occured! \(error.description)")), cause: error)
          }
        } else {
          if status == .completed {
            callback.resolve([
              "path": recordingSession.url.absoluteString,
              "duration": recordingSession.duration,
              "initialTimestamp": CMTimeGetSeconds(recordingSession.initialTimestamp ?? CMTime.invalid),
            ])
          } else {
            callback.reject(error: .unknown(message: "AVAssetWriter completed with status: \(status.descriptor)"))
          }
        }
      }

      let recordingSession: RecordingSession
      do {
        recordingSession = try RecordingSession(url: tempURL,
                                                fileType: fileType,
                                                completion: onFinish)
      } catch let error as NSError {
        callback.reject(error: .capture(.createRecorderError(message: nil)), cause: error)
        return
      }
      self.recordingSession = recordingSession

      var videoCodec: AVVideoCodecType?
      if let codecString = options["videoCodec"] as? String {
        videoCodec = AVVideoCodecType(withString: codecString)
      }

      // Init Video
      guard let videoSettings = self.recommendedVideoSettings(videoOutput: videoOutput, fileType: fileType, videoCodec: videoCodec),
            !videoSettings.isEmpty else {
        callback.reject(error: .capture(.createRecorderError(message: "Failed to get video settings!")))
        return
      }

      // get pixel format (420f, 420v, x420)
      let pixelFormat = CMFormatDescriptionGetMediaSubType(videoInput.device.activeFormat.formatDescription)
      var newSettings = videoSettings
      if let quality = options["quality"] as? Double, CMTIME_IS_VALID(videoInput.device.activeVideoMinFrameDuration) {
        let width = videoInput.device.activeFormat.videoDimensions.width
        let height = videoInput.device.activeFormat.videoDimensions.height
        let frameTime = CMTimeGetSeconds(videoInput.device.activeVideoMinFrameDuration)
        // quality 100 means 0.2 bits per pixel
        let magicQualityContant = 0.2 / 100.0
        let bitRate = magicQualityContant * quality * width * height / frameTime

        let compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: NSNumber(integerLiteral: Int(bitRate))
        ]
        newSettings[AVVideoCompressionPropertiesKey] = compressionProperties
      }
      recordingSession.initializeVideoWriter(withSettings: newSettings,
                                             pixelFormat: pixelFormat)

      // Init Audio (optional, async)
      if enableAudio {
        // Activate Audio Session (blocking)
        self.activateAudioSession()

        if let audioOutput = self.audioOutput,
           let audioSettings = audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: fileType) {
          recordingSession.initializeAudioWriter(withSettings: audioSettings)
        }
      }

      // start recording session with or without audio.
      do {
        try recordingSession.startAssetWriter()
      } catch let error as NSError {
        callback.reject(error: .capture(.createRecorderError(message: "RecordingSession failed to start asset writer.")), cause: error)
        return
      }
      self.recordingSession = recordingSession
      self.isRecording = true
      self.invokeOnRecordingStarted(videoPath: tempURL.absoluteString)
    }
  }

  func stopRecording(promise: Promise) {
    cameraQueue.async {
      self.isRecording = false

      withPromise(promise) {
        guard let recordingSession = self.recordingSession else {
          throw CameraError.capture(.noRecordingInProgress)
        }
        recordingSession.finish()
        return nil
      }
    }
  }

  func pauseRecording(promise: Promise) {
    cameraQueue.async {
      withPromise(promise) {
        guard self.recordingSession != nil else {
          // there's no active recording!
          throw CameraError.capture(.noRecordingInProgress)
        }
        self.isRecording = false
        return nil
      }
    }
  }

  func resumeRecording(promise: Promise) {
    cameraQueue.async {
      withPromise(promise) {
        guard self.recordingSession != nil else {
          // there's no active recording!
          throw CameraError.capture(.noRecordingInProgress)
        }
        self.isRecording = true
        return nil
      }
    }
  }

  public final func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
    // Video Recording runs in the same queue
    var timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    if isRecording {
      guard let recordingSession = recordingSession else {
        invokeOnError(.capture(.unknown(message: "isRecording was true but the RecordingSession was null!")))
        return
      }

      switch captureOutput {
      case is AVCaptureVideoDataOutput:
        recordingSession.appendBuffer(sampleBuffer, type: .video, timestamp: timestamp)
      case is AVCaptureAudioDataOutput:
        timestamp = CMSyncConvertTime(timestamp,
                                          from: audioCaptureSession.masterClock!,
                                          to: captureSession.masterClock!)
        recordingSession.appendBuffer(sampleBuffer, type: .audio, timestamp: timestamp)
      default:
        break
      }
      timestamp = recordingSession.initialTimestamp ?? CMTime.invalid
    }

    if let frameProcessor = audioFrameProcessorCallback, captureOutput is AVCaptureAudioDataOutput {
        if !isRunningAudioFrameProcessor {
            var bufferCopy : CMSampleBuffer?
            let err = CMSampleBufferCreateCopy(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer, sampleBufferOut: &bufferCopy)
            if err == noErr {
                // we're not in the middle of executing the Frame Processor, so prepare for next call.
                CameraQueues.frameProcessorQueue.async {
                    self.isRunningAudioFrameProcessor = true

                    //print("AVCaptureAudioDataOutput \(timestamp)\n")

                    let frame = Frame(buffer: bufferCopy!, orientation: self.bufferOrientation, timestamp: CMTimeGetSeconds(timestamp))
                    frameProcessor(frame)

                    self.isRunningAudioFrameProcessor = false
                }
            }
        } else {
            // we're still in the middle of executing a Frame Processor for a previous frame, so a frame was dropped.
            ReactLogger.log(level: .warning, message: "The Audio Frame Processor took so long to execute that a frame was dropped.")
        }
    }

    if let frameProcessor = videoFrameProcessorCallback, captureOutput is AVCaptureVideoDataOutput {
      // check if last frame was x nanoseconds ago, effectively throttling FPS
      let frameTime = UInt64(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds * 1_000_000_000.0)
      let lastFrameProcessorCallElapsedTime = frameTime - lastFrameProcessorCall
      let secondsPerFrame = 1.0 / actualFrameProcessorFps
      let nanosecondsPerFrame = secondsPerFrame * 1_000_000_000.0
      if lastFrameProcessorCallElapsedTime >= UInt64(nanosecondsPerFrame) {
        if !isRunningVideoFrameProcessor {
          // we're not in the middle of executing the Frame Processor, so prepare for next call.
          CameraQueues.frameProcessorQueue.async {
            self.isRunningVideoFrameProcessor = true

            let perfSample = self.frameProcessorPerformanceDataCollector.beginPerformanceSampleCollection()
            let frame = Frame(buffer: sampleBuffer, orientation: self.bufferOrientation, timestamp: CMTimeGetSeconds(timestamp))
            frameProcessor(frame)
            perfSample.endPerformanceSampleCollection()

            self.isRunningVideoFrameProcessor = false
          }
          lastFrameProcessorCall = frameTime
        } else {
          // we're still in the middle of executing a Frame Processor for a previous frame, so a frame was dropped.
          ReactLogger.log(level: .warning, message: "The Video Frame Processor took so long to execute that a frame was dropped.")
        }
      }

      if isReadyForNewEvaluation {
        // last evaluation was more than 1sec ago, evaluate again
        evaluateNewPerformanceSamples()
      }
    }
  }

  private func evaluateNewPerformanceSamples() {
    lastFrameProcessorPerformanceEvaluation = DispatchTime.now()
    guard let videoDevice = videoDeviceInput?.device else { return }
    guard frameProcessorPerformanceDataCollector.hasEnoughData else { return }

    let maxFrameProcessorFps = Double(videoDevice.activeVideoMinFrameDuration.timescale) * Double(videoDevice.activeVideoMinFrameDuration.value)
    let averageFps = 1.0 / frameProcessorPerformanceDataCollector.averageExecutionTimeSeconds
    let suggestedFrameProcessorFps = max(floor(min(averageFps, maxFrameProcessorFps)), 1)

    if frameProcessorFps.intValue == -1 {
      // frameProcessorFps="auto"
      actualFrameProcessorFps = suggestedFrameProcessorFps
    } else {
      // frameProcessorFps={someCustomFpsValue}
      invokeOnFrameProcessorPerformanceSuggestionAvailable(currentFps: frameProcessorFps.doubleValue,
                                                           suggestedFps: suggestedFrameProcessorFps)
    }
  }

  private func recommendedVideoSettings(videoOutput: AVCaptureVideoDataOutput, fileType: AVFileType, videoCodec: AVVideoCodecType?) -> [String: Any]? {
    if videoCodec != nil {
      return videoOutput.recommendedVideoSettings(forVideoCodecType: videoCodec!, assetWriterOutputFileType: fileType)
    } else {
      return videoOutput.recommendedVideoSettingsForAssetWriter(writingTo: fileType)
    }
  }

  private var isReadyForNewEvaluation: Bool {
    let lastPerformanceEvaluationElapsedTime = DispatchTime.now().uptimeNanoseconds - lastFrameProcessorPerformanceEvaluation.uptimeNanoseconds
    return lastPerformanceEvaluationElapsedTime > 1_000_000_000
  }

  /**
   Gets the orientation of the CameraView's images (CMSampleBuffers).
   */
  var bufferOrientation: UIImage.Orientation {
    guard let cameraPosition = videoDeviceInput?.device.position else {
      return .up
    }

    switch UIDevice.current.orientation {
    case .portrait:
      return cameraPosition == .front ? .leftMirrored : .right

    case .landscapeLeft:
      return cameraPosition == .front ? .downMirrored : .up

    case .portraitUpsideDown:
      return cameraPosition == .front ? .rightMirrored : .left

    case .landscapeRight:
      return cameraPosition == .front ? .upMirrored : .down

    case .unknown, .faceUp, .faceDown:
      fallthrough
    @unknown default:
      return .up
    }
  }
}
