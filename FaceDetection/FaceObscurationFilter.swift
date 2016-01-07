//
//  FaceObscurationFilter.swift
//  FaceDetection
//
//  Created by Ryan Davies on 07/01/2016.
//  Copyright © 2016 Ryan Davies. All rights reserved.
//

import Foundation
import AVFoundation
import CoreImage

class FaceObscurationFilter {
    let inputImage: CIImage
    var outputImage: CIImage? = nil
    
    init(inputImage: CIImage) {
        self.inputImage = inputImage
    }
    
    convenience init(sampleBuffer: CMSampleBuffer) {
        // Create a CIImage from the buffer
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let image = CIImage(CVPixelBuffer: imageBuffer!)
        
        self.init(inputImage: image)
    }
    
    func process() {
        // Detect any faces in the image
        let detector = CIDetector(ofType: CIDetectorTypeFace, context:nil, options:nil)
        let features = detector.featuresInImage(inputImage)
        
        print("Features: \(features)")
        
        // Build a pixellated version of the image using the CIPixellate filter
        let imageSize = inputImage.extent.size
        let pixellationOptions = [kCIInputScaleKey: max(imageSize.width, imageSize.height) / 10]
        let pixellation = CIFilter(name: "CIPixellate", withInputParameters: pixellationOptions)
        let pixellatedImage = pixellation!.outputImage!
        
        // Build a masking image for each of the faces
        var maskImage: CIImage? = nil
        for feature in features {
            // Get feature position and radius for circle
            let xCenter = feature.bounds.origin.x + feature.bounds.size.width / 2.0
            let yCenter = feature.bounds.origin.y + feature.bounds.size.height / 2.0
            let radius = min(feature.bounds.size.width, feature.bounds.size.height) / 1.5
            
            // Input parameters for the circle filter
            var circleOptions: [String: AnyObject] = [:]
            circleOptions["inputRadius0"] = radius
            circleOptions["inputRadius1"] = radius + 1
            circleOptions["inputColor0"] = CIColor(red: 0, green: 1, blue: 0, alpha: 1)
            circleOptions["inputColor1"] = CIColor(red: 0, green: 0, blue: 0, alpha: 1)
            circleOptions[kCIInputCenterKey] = CIVector(x: xCenter, y: yCenter)
            
            // Create radial gradient circle at face position with face radius
            let radialGradient = CIFilter(name: "CIRadialGradient", withInputParameters: circleOptions)
            let circleImage = radialGradient!.outputImage!
            
            if maskImage != nil {
                // If the mask image is already set, create a composite of both the
                // new circle image and the old so we're creating one image with all
                // of the circles in it.
                let options: [String: AnyObject] = [kCIInputImageKey: circleImage, kCIInputBackgroundImageKey: maskImage!]
                let composition = CIFilter(name: "CISourceOverCompositing", withInputParameters: options)!
                maskImage = composition.outputImage
            } else {
                // If it's not set, remember it for composition next time.
                maskImage = circleImage;
            }
        }
        
        // Create a single blended image made up of the pixellated image, the mask image, and the original image.
        // We want sections of the pixellated image to be removed according to the mask image, to reveal
        // the original image in the background.
        // We use the CIBlendWithMask filter for this, and set the background image as the original image,
        // the input image (the one to be masked) as the pixellated image, and the mask image as, well, the mask.
        var blendOptions: [String: AnyObject] = [:]
        blendOptions[kCIInputImageKey] = pixellatedImage
        blendOptions[kCIInputBackgroundImageKey] = inputImage
        blendOptions[kCIInputMaskImageKey] = maskImage
        
        if let blend = CIFilter(name: "CIBlendWithMask", withInputParameters: blendOptions) {
            // Finally, set the resulting image as the output
            outputImage = blend.outputImage
        }
    }
}
