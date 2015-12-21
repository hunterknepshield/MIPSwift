//
//  SoundManager.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/20/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

// Original source: https://gist.github.com/rgcottrell/5b876d9c5eea4c9e411c

import Foundation
import AVFoundation

/// The maximum number of audio buffers in flight. Setting to two allows one
/// buffer to be played while the next is being written.
private let kInFlightAudioBuffers: Int = 2

/// The number of audio samples per buffer. A lower value reduces latency for
/// changes but requires more processing but increases the risk of being unable
/// to fill the buffers in time. A setting of 1024 represents about 23ms of
/// samples.
private let kSamplesPerBuffer: AVAudioFrameCount = 1024

public class SoundManager {
	/// The audio engine manages the sound system.
	let engine = AVAudioEngine()
	/// The player node schedules the playback of the audio buffers.
	let playerNode = AVAudioPlayerNode()
	/// Use standard non-interleaved PCM audio.
	let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)
	/// A circular queue of audio buffers.
	private var audioBuffers = [AVAudioPCMBuffer]()
	/// The index of the next buffer to fill.
	private var bufferIndex = 0
	/// The dispatch queue to render audio samples.
	private let audioQueue = dispatch_queue_create("FMSynthesizerQueue", DISPATCH_QUEUE_SERIAL)
	/// A semaphore to gate the number of buffers processed.
	private let audioSemaphore = dispatch_semaphore_create(kInFlightAudioBuffers)
	
	init() {
		// Create a pool of audio buffers.
		for var i = 0;  i < kInFlightAudioBuffers; i++ {
			let audioBuffer = AVAudioPCMBuffer(PCMFormat: audioFormat, frameCapacity: kSamplesPerBuffer)
			audioBuffers.append(audioBuffer)
		}
		
		// Attach and connect the player node.
		engine.attachNode(playerNode)
		engine.connect(playerNode, to: engine.mainMixerNode, format: audioFormat)
		
		do {
			try engine.start()
		} catch let err {
			print("Error starting audio engine: \(err)")
		}
	}
	
	func play(carrierFrequency: Float32, modulatorFrequency: Float32, modulatorAmplitude: Float32) {
		let unitVelocity = Float32(2.0 * M_PI / audioFormat.sampleRate)
		let carrierVelocity = carrierFrequency * unitVelocity
		let modulatorVelocity = modulatorFrequency * unitVelocity
		dispatch_async(audioQueue) {
			var sampleTime: Float32 = 0
			while true {
				// Wait for a buffer to become available
				dispatch_semaphore_wait(self.audioSemaphore, DISPATCH_TIME_FOREVER)
				
				// Fill the buffer with new samples
				let audioBuffer = self.audioBuffers[self.bufferIndex]
				let leftChannel = audioBuffer.floatChannelData[0]
				let rightChannel = audioBuffer.floatChannelData[1]
				for var sampleIndex = 0; sampleIndex < Int(kSamplesPerBuffer); sampleIndex++ {
					let sample = sin(carrierVelocity * sampleTime + modulatorAmplitude * sin(modulatorVelocity * sampleTime))
					leftChannel[sampleIndex] = sample
					rightChannel[sampleIndex] = sample
					sampleTime++
				}
				audioBuffer.frameLength = kSamplesPerBuffer
				
				// Schedule the buffer for playback and release it for reuse after playback has finished
				self.playerNode.scheduleBuffer(audioBuffer) {
					dispatch_semaphore_signal(self.audioSemaphore)
					return
				}
				
				self.bufferIndex = (self.bufferIndex + 1) % self.audioBuffers.count
			}
		}
		
		playerNode.pan = 0.8
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC.signed), dispatch_get_main_queue(), {
			self.playerNode.stop()
			print("Stopped")
		})
		playerNode.play()
	}
}