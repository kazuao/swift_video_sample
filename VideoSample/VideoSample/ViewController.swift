//
//  ViewController.swift
//  VideoSample
//
//  Created by Kazunori Aoki on 2021/04/02.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    // MARK: Property
    @IBOutlet weak var recordBtn: UIButton!
    @IBOutlet weak var cameraView: UIView!
    
    // movieのキャプチャ出力オブジェクト
    let fileOutput = AVCaptureMovieFileOutput()
    let captureSession = AVCaptureSession()
    
    // MARK: LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCamera()
        setupView()
        
        //画面向きを左横画面でセットする
        UIDevice.current.setValue(4, forKey: "orientation")
        
        //画面の向きを変更させるために呼び出す。
        print(supportedInterfaceOrientations)
    }
    
    // MARK: Setup
    func setupView() {
        recordBtn.backgroundColor = UIColor.red
        recordBtn.clipsToBounds = true
        recordBtn.layer.cornerRadius = min(recordBtn.frame.width, recordBtn.frame.height) / 2
    }
    
    func setupCamera() {
        // 最長60秒に指定
        fileOutput.maxRecordedDuration = CMTimeMake(value: 60, timescale: 1)
        
        setupImageQuality()
        
        // 通常のレンズかつ、ビデオモードで、フロントカメラを使用する
        let deviceDiscoverySession
            = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
                                               mediaType: AVMediaType.video,
                                               position: AVCaptureDevice.Position.front)
        
        // 使用できるデバイスの一覧を取得
        let devices = deviceDiscoverySession.devices
        var innerCamera: AVCaptureDevice?
        for device in devices {
            // 使用できるデバイスの中からフロントカメラを選択
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
        // 画像の位置決め、今回はStoryboard上で16:9に設定している
        let videoLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        // safeエリアのありなしで、viewの設定方法を変更する
        let safeAreaInsets = UIApplication.shared.windows.first?.safeAreaInsets.left
        if (safeAreaInsets != 0.0) {
            videoLayer.frame = cameraView.frame
        } else {
            videoLayer.frame = cameraView.bounds
        }
        
        videoLayer.videoGravity = .resizeAspectFill
        // 画角を横固定に
        videoLayer.connection?.videoOrientation = .landscapeRight
        cameraView.layer.addSublayer(videoLayer)
    }
    
    func setupImageQuality() {
        captureSession.beginConfiguration()
        
        // .highを設定すると、16:9の画角になる
        captureSession.sessionPreset = .high
        
        captureSession.commitConfiguration()
    }
    
    // 横画面固定にする
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        
        //左横画面に変更
        if (UIDevice.current.orientation.rawValue == 4) {
            UIDevice.current.setValue(4, forKey: "orientation")
            return .landscapeLeft
            
        } else {
            //最初の画面呼び出しで画面を右横画面に変更させる。
            UIDevice.current.setValue(3, forKey: "orientation")
            return .landscapeRight
        }
    }
    
    // 画面を自動で回転させるかを決定する。
    override var shouldAutorotate: Bool {
        
        //画面が縦だった場合は回転させない
        if (UIDevice.current.orientation.rawValue == 1) {
            return false
        } else {
            return true
        }
    }
    
    // MARK: IBAction
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

// MARK: AVCaptureFileOutputRecordingDelegate
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
