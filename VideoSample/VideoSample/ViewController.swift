//
//  ViewController.swift
//  VideoSample
//
//  Created by Kazunori Aoki on 2021/04/02.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var recordBtn: UIButton!
    
    // movieのキャプチャ出力オブジェクト
    let fileOutput = AVCaptureMovieFileOutput()
    let captureSession = AVCaptureSession()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCamera()
        setupBtn()
    }
    
    func setupBtn() {
        recordBtn.layer.borderColor = UIColor.black.cgColor
        recordBtn.layer.borderWidth = 5
        recordBtn.backgroundColor = UIColor.red
        recordBtn.clipsToBounds = true
        recordBtn.layer.cornerRadius = min(recordBtn.frame.width, recordBtn.frame.height) / 2
    }
    
    func setupCamera() {
        // 最長120秒に指定
        fileOutput.maxRecordedDuration = CMTimeMake(value: 120, timescale: 1)
        
        setupImageQuality()
        
        // 通常のレンズかつ、ビデオモードで、フロントカメラを使用する
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
                                                                      mediaType: AVMediaType.video,
                                                                      position: AVCaptureDevice.Position.front)
        let devices = deviceDiscoverySession.devices
        var innerCamera: AVCaptureDevice?
        for device in devices {
            if device.position == AVCaptureDevice.Position.front {
                innerCamera = device
            }
        }
        
        let audioDevice = AVCaptureDevice.default(for: AVMediaType.audio)
        
        // video input setting
        let videoInput = try! AVCaptureDeviceInput(device: innerCamera!)
        captureSession.addInput(videoInput)
        
        // audio input setting
        let audioInput = try! AVCaptureDeviceInput(device: audioDevice!)
        captureSession.addInput(audioInput)
        
        captureSession.addOutput(fileOutput)
        
        captureSession.startRunning()
        
        // video preview layer
        let videoLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoLayer.frame = self.view.bounds
        videoLayer.videoGravity = .resizeAspectFill
        self.view.layer.addSublayer(videoLayer)
    }
    
    func setupImageQuality() {
        captureSession.beginConfiguration()
        
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        } else if captureSession.canSetSessionPreset(.medium) {
            captureSession.sessionPreset = .medium
        }
        
        captureSession.commitConfiguration()
    }
    
    @IBAction func onClickRecordBtn(_ sender: Any) {
        if fileOutput.isRecording {
            // stop recording
            fileOutput.stopRecording()
            
            self.recordBtn.backgroundColor = .gray
            self.recordBtn.setTitle("Record", for: .normal)
        } else {
            // start recording
            let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            let fileURL = tempDirectory.appendingPathComponent("mytemp1.mov")
            
            fileOutput.startRecording(to: fileURL, recordingDelegate: self)
            
            self.recordBtn.backgroundColor = .red
            self.recordBtn.setTitle("●Recording", for: .normal)
        }
    }
}

extension ViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {

        // どこのディレクトリに保存するか
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentDirectory.appendingPathComponent("hogehoge.mp4")
        
        // 保存したいファイルタイプ
        let fileType = AVFileType.mp4
        
        exportMovie(sourceURL: outputFileURL, destinationURL: destinationURL, fileType: fileType)
        // show alert
        let alert = UIAlertController(title: "Recorded!", message: outputFileURL.absoluteString, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil)
        alert.addAction(okAction)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func exportMovie(sourceURL: URL, destinationURL: URL, fileType: AVFileType) {
        
        let avAsset = AVAsset(url: sourceURL)
        
        // videoとaudioのトラックをそれぞれ取得
        let videoTrack = avAsset.tracks(withMediaType: .video)[0]
        let audioTracks = avAsset.tracks(withMediaType: .audio)
        let audioTrack = audioTracks.count > 0 ? audioTracks[0] : nil
        
        let mainComposition = AVMutableComposition()
        
        // videoとaudioのコンポジショントラックをそれぞれ作成
        let compositionVideoTrack = mainComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        let compositionAudioTrack = audioTrack != nil
                                    ? mainComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
                                    : nil
        
        // コンポジションの設定
        try! compositionVideoTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: avAsset.duration), of: videoTrack, at: CMTime.zero)
        try! compositionAudioTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: avAsset.duration), of: audioTrack!, at: CMTime.zero)
        
        // エクスポートするためのセッションを作成
        let assetExxport = AVAssetExportSession.init(asset: mainComposition, presetName: AVAssetExportPresetMediumQuality)
        
        // エクスポートするファイルの種類を設定
        assetExxport?.outputFileType = fileType
        
        // エクスポート先URLを設定
        assetExxport?.outputURL = destinationURL
        
        // エクスポート先URLにすでにファイルが存在していれば削除する（上書きはできないよう）
        if FileManager.default.fileExists(atPath: (assetExxport?.outputURL?.path)!) {
            try! FileManager.default.removeItem(atPath: (assetExxport?.outputURL?.path)!)
        }
        
        // エクスポートする
        assetExxport?.exportAsynchronously(completionHandler: {
            // エクスポート完了後に実行する処理
        })
    }
}
