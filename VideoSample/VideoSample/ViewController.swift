//
//  ViewController.swift
//  VideoSample
//
//  Created by Kazunori Aoki on 2021/04/02.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    // ここを変更して動画の構成を変更する
    private let componentType = ".mp4"
    private let sessionPreset: AVCaptureSession.Preset = .hd1280x720
    private let codecType: AVVideoCodecType = AVVideoCodecType.hevc
    private let fpsRate: Int32 = 30
    
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
        
        // video input setting
        let videoInput = try! AVCaptureDeviceInput(device: innerCamera!)
        captureSession.addInput(videoInput)
        
        
        // 音声を入れる場合は、コメントアウトを外す。
        // audio input setting
//        let audioDevice = AVCaptureDevice.default(for: AVMediaType.audio)
//        let audioInput = try! AVCaptureDeviceInput(device: audioDevice!)
//        captureSession.addInput(audioInput)
        
        captureSession.addOutput(fileOutput)
        
        let connection = fileOutput.connection(with: .video)
        // コーデックタイプの変更
        fileOutput.setOutputSettings([AVVideoCodecKey: codecType], for: connection!)
        
        let videoDataOutputConnection = fileOutput.connection(with: .video)
        fileOutput.setRecordsVideoOrientationAndMirroringChangesAsMetadataTrack(true, for: videoDataOutputConnection!)
        
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
        
        /**
         * hd1920x1080: 1080p
         * hd1280x720: 720p
         * .high: 16:9 high-quality
         */
        if captureSession.canSetSessionPreset(sessionPreset) {
            captureSession.sessionPreset = sessionPreset
        } else {
            captureSession.sessionPreset = .hd1280x720
        }
        
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
            
            fileOutput.stopRecording()
            
            self.recordBtn.backgroundColor = .gray
            self.recordBtn.setTitle("Record", for: .normal)
            
        } else {
        
            let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            let fileURL = tempDirectory.appendingPathComponent("mytemp1" + componentType)
            
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
        // 保存するファイル名
        let destinationURL = documentDirectory.appendingPathComponent("hogehoge.mp4")
        // 保存したいファイルタイプ
        let fileType = AVFileType.mp4

        // export処理
        exportMovie(sourceURL: outputFileURL, destinationURL: destinationURL, fileType: fileType)

        // show alert
        let alert = UIAlertController(title: "Recorded!", message: outputFileURL.absoluteString, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil)
        alert.addAction(okAction)

        self.present(alert, animated: true, completion: nil)
    }
    
    func exportMovie(sourceURL: URL, destinationURL: URL, fileType: AVFileType) {
        
        let avAsset = AVAsset(url: sourceURL)
        let mainComposition = AVMutableComposition()
        
        // video トラックの取得
        let videoTrack = avAsset.tracks(withMediaType: .video)[0]
        // videoのコンポジショントラックを作成
        let compositionVideoTrack = mainComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        // コンポジションの設定
        try! compositionVideoTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: avAsset.duration), of: videoTrack, at: CMTime.zero)
        
        // audioを使用する場合はコメントアウトを外す
//        let audioTracks = avAsset.tracks(withMediaType: .audio)
//        let audioTrack = audioTracks.count > 0 ? audioTracks[0] : nil
//        let compositionAudioTrack = audioTrack != nil
//            ? mainComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
//            : nil
//        try! compositionAudioTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: avAsset.duration), of: audioTrack!, at: CMTime.zero)
        
        
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
            // TODO: APIリクエスト等行う？
            self.compression(beforeMovieUrl: destinationURL)
        })
    }
    
    func compression(beforeMovieUrl: URL) {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let videoURL: URL = tempDirectory.appendingPathComponent("\(Date())tmpMovieSample.mov")
        //コンポジション作成
        let mixComposition : AVMutableComposition = AVMutableComposition()
        //アセットの作成
        //動画のアセットとトラックを作成
        let videoAsset: AVURLAsset = AVURLAsset(url: beforeMovieUrl, options:nil)
        // 元の動画ファイルから、動画（音声なし）トラックの取得
        let videoTrack: AVAssetTrack = (videoAsset.tracks(withMediaType: AVMediaType.video))[0]
        // ベースとなる動画のコンポジション作成
        let compositionVideoTrack: AVMutableCompositionTrack! = mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
        // 動画の長さ設定
        try! compositionVideoTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration), of: videoTrack, at: CMTime.zero)
        // 音声付きの動画か判定
        if videoAsset.tracks(withMediaType: AVMediaType.audio).count > 0 {
            // 音声付き動画の場合、音声を取得し設定する
            // 元の動画ファイルから、オーディオトラックの取得
            let audioTrack: AVAssetTrack = (videoAsset.tracks(withMediaType: AVMediaType.audio))[0]
            // ベースとなる音声のコンポジション作成
            let compositionAudioTrack: AVMutableCompositionTrack! = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            // 音声の長さ設定
            try! compositionAudioTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration), of: audioTrack, at: CMTime.zero)
        }
        // 回転方向の設定
        compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
        // 動画のサイズを取得
        var videoSize: CGSize = videoTrack.naturalSize
        // 動画が縦の場合は「true」で、横の場合には「false」が入る
        var isPortrait: Bool = false
        // ビデオを縦横方向
        let transform: CGAffineTransform = videoTrack.preferredTransform
        // 動画が縦かどうかを判定する
        if (transform.a == 0 && transform.d == 0 && (transform.b == 1.0 || transform.b == -1.0) && (transform.c == 1.0 || transform.c == -1.0)) {
            // 動画が縦の場合
            isPortrait = true
            // 「videoSize」に設定している「高さ」と「幅」を反転させる（デフォルトが横向きのサイズの為）
            videoSize = CGSize(width: videoSize.height, height: videoSize.width)
        }
        // 合成用コンポジション作成
        let videoComp: AVMutableVideoComposition = AVMutableVideoComposition()
        videoComp.renderSize = videoSize
        // フレームレートの設定
        // TODO: ここの値を調整する事で、動画のフレームレートを落として、容量の削減につながる
        videoComp.frameDuration = CMTimeMake(value: 1, timescale: fpsRate)
        // インストラクションを合成用コンポジションに設定
        let instruction: AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration)
        let layerInstruction: AVMutableVideoCompositionLayerInstruction = AVMutableVideoCompositionLayerInstruction.init(assetTrack: compositionVideoTrack)
        instruction.layerInstructions = [layerInstruction]
        videoComp.instructions = [instruction]
        if isPortrait {
            // 動画が縦の場合
            // 動画を90％回す（「AVAssetExportSession」を使用する場合には、縦の場合でも横向きで表示される為、90％回す必要がある）
            let FirstAssetScaleFactor: CGAffineTransform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            layerInstruction.setTransform(videoTrack.preferredTransform.concatenating(FirstAssetScaleFactor), at: CMTime.zero)
        }
        // 動画のコンポジションをベースにAVAssetExportを生成
        let _assetExport = AVAssetExportSession.init(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
        // 合成用コンポジションを設定
        _assetExport?.videoComposition = videoComp
        let exportUrl: URL = videoURL
        _assetExport?.outputFileType = AVFileType.mp4
        _assetExport?.outputURL = exportUrl
        _assetExport?.shouldOptimizeForNetworkUse = true
        // エクスポート実行
        _assetExport?.exportAsynchronously(completionHandler: {() -> Void in
            if _assetExport?.status == AVAssetExportSession.Status.failed {
                // 失敗した場合
            }
            if _assetExport?.status == AVAssetExportSession.Status.completed {
                // 成功した場合
            }
        })
    }
}
