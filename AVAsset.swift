//
//  AVAsset.swift
//  Capture
//
//  Created by Glen Hinkle on 2/2/16.
//  Copyright © 2016 Zombie Dolphin. All rights reserved.
//

import Foundation
import AVKit

extension AVAsset {
    func reversedAsset(outputURL: NSURL) -> AVAsset? {
        do {
            let reader = try AVAssetReader(asset: self)

            guard let videoTrack = tracksWithMediaType(AVMediaTypeVideo).last else {
                return .None
            }

            let readerOutputSettings: [String:AnyObject] = [
                "\(kCVPixelBufferPixelFormatTypeKey)": Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)

            reader.addOutput(readerOutput)
            reader.startReading()

            // Read in frames (CMSampleBuffer is a frame)
            var samples = [CMSampleBuffer]()
            while let sample = readerOutput.copyNextSampleBuffer() {
                samples.append(sample)
            }

            // Write to AVAsset
            let writer = try AVAssetWriter(URL: outputURL, fileType: AVFileTypeMPEG4)

            let writerOutputSettings: [String:AnyObject] = [
                AVVideoCodecKey: AVVideoCodecH264,
                AVVideoWidthKey: videoTrack.naturalSize.width,
                AVVideoHeightKey: videoTrack.naturalSize.height,
                AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: videoTrack.estimatedDataRate]
            ]

            let sourceFormatHint = videoTrack.formatDescriptions.last as! CMFormatDescriptionRef
            let writerInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: writerOutputSettings, sourceFormatHint: sourceFormatHint)
            writerInput.expectsMediaDataInRealTime = false

            let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: .None)
            writer.addInput(writerInput)
            writer.startWriting()
            writer.startSessionAtSourceTime(CMSampleBufferGetPresentationTimeStamp(samples[0]))

            for (index, sample) in samples.enumerate() {
                let presentationTime = CMSampleBufferGetPresentationTimeStamp(sample)

                if let imageBufferRef = CMSampleBufferGetImageBuffer(samples[samples.count - index - 1]) {
                    pixelBufferAdaptor.appendPixelBuffer(imageBufferRef, withPresentationTime: presentationTime)
                }

                while !writerInput.readyForMoreMediaData {
                    NSThread.sleepForTimeInterval(0.1)
                }
            }

            writer.finishWritingWithCompletionHandler { }
            return AVAsset(URL: outputURL)
        }
        catch let error as NSError {
            print("\(error)")
            return .None
        }
    }
}
