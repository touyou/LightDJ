//
//  WorkSpace.swift
//  LightDJ
//
//  Created by 藤井陽介 on 2016/04/19.
//  Copyright © 2016年 touyou. All rights reserved.
//

import UIKit
import AudioToolbox
import MediaPlayer
import C4

private func AudioQueueInputCallback(
    _ inUserData: UnsafeMutableRawPointer?,
    inAQ: AudioQueueRef,
    inBuffer: AudioQueueBufferRef,
    inStartTime: UnsafePointer<AudioTimeStamp>,
    inNumberPacketDescriptions: UInt32,
    inPacketDescs: UnsafePointer<AudioStreamPacketDescription>?)
{
    // Do nothing, because not recoding.
}

class WorkSpace: CanvasController, MPMediaPickerControllerDelegate {
    
    var modeCnt = 5
    
    var queue: AudioQueueRef!
    var timer: Foundation.Timer!
    var colorWeight: [Double] = [0.0, 0.0, 0.0]
    var circle: Circle?
    var square: Rectangle?
    var star: Star?
    var regularPol: RegularPolygon?
    var mediaItems = [MPMediaItem]()
    var mediaPlayer: AudioPlayer?
    var nowPlaying: Int = 0
    
    override func setup() {
        prepareInput()
        //Work your magic here.
        // タップで色を変える
        canvas.addTapGestureRecognizer({ location, center, state in
            // Finish observation
            self.timer.invalidate()
            self.timer = nil
            self.startMode(random(in: 0..<self.modeCnt))
        })
        startMode(random(in: 0..<modeCnt))
        
        // ドット柄
        let maxDistance = distance(Point(), rhs: canvas.center)
        var pt = Point(8, 8)
        repeat {
            repeat {
                let c = Circle(center: pt, radius: 0.5)
                let d = distance(pt, rhs: canvas.center) / maxDistance
                c.lineWidth = 0.0
                c.fillColor = Color(red: d, green: d, blue: d, alpha: 1.0)
                canvas.add(c)
                pt.x += 10.0
            } while pt.x < canvas.width
            pt.y += 10.0
            pt.x = 8.0
        } while pt.y < canvas.height
        
        // なぞるとパーティクルが出る感じ
        canvas.addPanGestureRecognizer { locations, center, translation, velocity, state in
            ShapeLayer.disableActions = true
            let circle = Circle(center: center, radius: 5)
            circle.fillColor = Color(red: self.colorWeight[0], green: self.colorWeight[1], blue: self.colorWeight[2], alpha: 0.9)
            self.canvas.add(circle)
            ShapeLayer.disableActions = false
            
            let a = ViewAnimation(duration: 1.0) {
                circle.opacity = 0.0
                circle.transform.scale(0.01, 0.01)
                circle.center = Point(center.x + (random(in: 0..<1)-0.5) * self.canvas.width,
                                    center.y + (random(in: 0..<1)-0.5) * self.canvas.height)
            }
            a.addCompletionObserver {
                circle.removeFromSuperview()
            }
            a.curve = .linear
            a.animate()
        }

        // 音楽を選ぶ
        let picker = MPMediaPickerController()
        picker.delegate = self
        picker.allowsPickingMultipleItems = true
        present(picker, animated: true, completion: nil)
        // ピンチで曲変更
        canvas.addPinchGestureRecognizer {_,_,_,_,_ in
            if self.mediaPlayer != nil {
                self.mediaPlayer?.pause()
            }
            self.mediaPlayer = nil
            self.mediaItems = []
            let picker = MPMediaPickerController()
            picker.delegate = self
            picker.allowsPickingMultipleItems = true
            self.present(picker, animated: true, completion: nil)
        }
    }
    
    // MARK: - Music
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        defer {
            dismiss(animated: true, completion: nil)
        }
        mediaItems = mediaItemCollection.items
        if mediaItems.isEmpty {
            return
        }
        let item = mediaItems[0]
        nowPlaying = 0
        playMedia(item)
    }
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        mediaPlayer = nil
        dismiss(animated: true, completion: nil)
    }
    func playMedia(_ mediaItem: MPMediaItem) {
        if let url = mediaItem.assetURL {
            mediaPlayer = AudioPlayer(url.absoluteString)
            mediaPlayer?.loops = false
            mediaPlayer?.play()
        }
    }
    func playNext() {
        if !mediaPlayer!.playing {
            nowPlaying += 1
            if nowPlaying < mediaItems.count {
                playMedia(mediaItems[nowPlaying])
            } else {
                mediaPlayer = nil
            }
        }
    }
    
    // MARK: - Input
    // http://blog.koogawa.com/entry/2016/04/17/133052を参考に
    func prepareInput() {
        // マイクの設定
        var dataFormat = AudioStreamBasicDescription(mSampleRate: 44100.0, mFormatID: kAudioFormatLinearPCM, mFormatFlags: AudioFormatFlags(kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked), mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
        // Observe input level
        var audioQueue: AudioQueueRef? = nil
        var error = noErr
        error = AudioQueueNewInput(
            &dataFormat,
            AudioQueueInputCallback,
            Unmanaged.passUnretained(self).toOpaque(),
            .none,
            .none,
            0,
            &audioQueue)
        if error == noErr {
            self.queue = audioQueue
        }
        AudioQueueStart(self.queue, nil)
        var enabledLevelMeter: UInt32 = 1
        AudioQueueSetProperty(self.queue, kAudioQueueProperty_EnableLevelMetering, &enabledLevelMeter, UInt32(MemoryLayout<UInt32>.size))
    }
    
    func startMode(_ mode: Int) {
        // 色の設定
        for i in 0..<3 {
            colorWeight[i] = random(in: 0..<1)
        }
        
        changeMode()
        
        // modeごとにselectorを変更する
        switch mode {
        case 1:
            self.timer = Foundation.Timer.scheduledTimer(timeInterval: 0.1,
                                                                target: self,
                                                                selector: #selector(WorkSpace.circleMode),
                                                                userInfo: nil,
                                                                repeats: true)
        case 2:
            self.timer = Foundation.Timer.scheduledTimer(timeInterval: 0.1,
                                                                target: self,
                                                                selector: #selector(WorkSpace.squareMode),
                                                                userInfo: nil,
                                                                repeats: true)
        case 3:
            self.timer = Foundation.Timer.scheduledTimer(timeInterval: 0.1,
                                                                target: self,
                                                                selector: #selector(WorkSpace.starMode),
                                                                userInfo: nil,
                                                                repeats: true)
        case 4:
            self.timer = Foundation.Timer.scheduledTimer(timeInterval: 0.1,
                                                                target: self,
                                                                selector: #selector(WorkSpace.regMode),
                                                                userInfo: nil,
                                                                repeats: true)
        case 0:
            self.timer = Foundation.Timer.scheduledTimer(timeInterval: 0.1,
                                                                target: self,
                                                                selector: #selector(WorkSpace.noObject),
                                                                userInfo: nil,
                                                                repeats: true)
        default: break
        }
        timer.fire()
    }
    
    @objc func noObject() {
        var level = 0.0
        if mediaPlayer == nil {
            var levelMeter = AudioQueueLevelMeterState()
            var propertySize = UInt32(MemoryLayout<AudioQueueLevelMeterState>.size)
            AudioQueueGetProperty(
                self.queue,
                kAudioQueueProperty_CurrentLevelMeterDB,
                &levelMeter,
                &propertySize)
            level = Double(levelMeter.mAveragePower)
        } else {
            level = -random(in: 0..<1) * (mediaPlayer!.currentTime / mediaPlayer!.duration) * 100.0
            playNext()
        }
        canvas.backgroundColor = Color(red: 0.9 - (level / 100) * colorWeight[0],
                                       green: 0.9 - (level / 100) * colorWeight[1],
                                       blue: 0.9 - (level / 100) * colorWeight[2],
                                       alpha: 1.0)
    }

    @objc func circleMode() {
        var level = 0.0
        if mediaPlayer == nil {
            var levelMeter = AudioQueueLevelMeterState()
            var propertySize = UInt32(MemoryLayout<AudioQueueLevelMeterState>.size)
            AudioQueueGetProperty(
                self.queue,
                kAudioQueueProperty_CurrentLevelMeterDB,
                &levelMeter,
                &propertySize)
            level = Double(levelMeter.mAveragePower)
        } else {
            level = -random(in: 0..<1) * (mediaPlayer!.currentTime / mediaPlayer!.duration) * 100.0
            playNext()
        }
        clearAll()
        circle = Circle(center: canvas.center, radius: 100.0+level)
        circle!.fillColor = Color(red: colorWeight[0], green: colorWeight[1], blue: colorWeight[2], alpha: 1.0)
        canvas.add(circle)
        canvas.backgroundColor = Color(red: 0.9 - (level / 100) * colorWeight[0],
                                       green: 0.9 - (level / 100) * colorWeight[1],
                                       blue: 0.9 - (level / 100) * colorWeight[2],
                                       alpha: 1.0)

    }
    
    @objc func squareMode() {
        // Get level
        var level = 0.0
        if mediaPlayer == nil {
            var levelMeter = AudioQueueLevelMeterState()
            var propertySize = UInt32(MemoryLayout<AudioQueueLevelMeterState>.size)
            AudioQueueGetProperty(
                self.queue,
                kAudioQueueProperty_CurrentLevelMeterDB,
                &levelMeter,
                &propertySize)
            level = Double(levelMeter.mAveragePower)
        } else {
            level = -random(in: 0..<1) * (mediaPlayer!.currentTime / mediaPlayer!.duration) * 100.0
            playNext()
        }
        clearAll()
        square = Rectangle(frame: Rect(0, 0, (100+level)*1.5, (100+level)*1.5))
        square!.center = canvas.center
        square!.fillColor = Color(red: colorWeight[0], green: colorWeight[1], blue: colorWeight[2], alpha: 1.0)
        canvas.add(square)
        canvas.backgroundColor = Color(red: 0.9 - (-level / 100) * colorWeight[0],
                                       green: 0.9 - (level / 100) * colorWeight[1],
                                       blue: 0.9 - (level / 100) * colorWeight[2],
                                       alpha: 1.0)
    }
    
    @objc func starMode() {
        var level = 0.0
        if mediaPlayer == nil {
            var levelMeter = AudioQueueLevelMeterState()
            var propertySize = UInt32(MemoryLayout<AudioQueueLevelMeterState>.size)
            AudioQueueGetProperty(
                self.queue,
                kAudioQueueProperty_CurrentLevelMeterDB,
                &levelMeter,
                &propertySize)
            level = Double(levelMeter.mAveragePower)
        } else {
            level = -random(in: 0..<1) * (mediaPlayer!.currentTime / mediaPlayer!.duration) * 100.0
            playNext()
        }
        clearAll()
        star = Star(center: canvas.center, pointCount: 5, innerRadius: (100.0+level)/2, outerRadius: 100.0+level)
        star!.fillColor = Color(red: colorWeight[0], green: colorWeight[1], blue: colorWeight[2], alpha: 1.0)
        canvas.add(star)
        canvas.backgroundColor = Color(red: 0.9 - (level / 100) * colorWeight[0],
                                       green: 0.9 - (level / 100) * colorWeight[1],
                                       blue: 0.9 - (level / 100) * colorWeight[2],
                                       alpha: 1.0)
        
    }
    
    @objc func regMode() {
        var level = 0.0
        if mediaPlayer == nil {
            var levelMeter = AudioQueueLevelMeterState()
            var propertySize = UInt32(MemoryLayout<AudioQueueLevelMeterState>.size)
            AudioQueueGetProperty(
                self.queue,
                kAudioQueueProperty_CurrentLevelMeterDB,
                &levelMeter,
                &propertySize)
            level = Double(levelMeter.mAveragePower)
        } else {
            level = -random(in: 0..<1) * (mediaPlayer!.currentTime / mediaPlayer!.duration) * 100.0
            playNext()
        }
        clearAll()
        regularPol = RegularPolygon(center: canvas.center, radius: 100.0+level, sides: 6, phase: 0.0)
        regularPol!.fillColor = Color(red: colorWeight[0], green: colorWeight[1], blue: colorWeight[2], alpha: 1.0)
        canvas.add(regularPol)
        canvas.backgroundColor = Color(red: 0.9 - (level / 100) * colorWeight[0],
                                       green: 0.9 - (level / 100) * colorWeight[1],
                                       blue: 0.9 - (level / 100) * colorWeight[2],
                                       alpha: 1.0)
    }
    
    func clearAll() {
        if circle != nil {
            circle!.removeFromSuperview()
        }
        if square != nil {
            square!.removeFromSuperview()
        }
        if star != nil {
            star!.removeFromSuperview()
        }
        if regularPol != nil {
            regularPol!.removeFromSuperview()
        }
    }
    
    func changeMode() {
        clearAll()
        circle = nil
        square = nil
        star = nil
        regularPol = nil
    }
}

