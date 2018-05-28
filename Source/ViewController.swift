import UIKit

let imageSize:Int = 600

class ViewController: UIViewController {
    var scene:Scene! = nil
    var timer = Timer()
    let queue = DispatchQueue(label: "Queue")
    lazy var device: MTLDevice! = MTLCreateSystemDefaultDevice()
    lazy var commandQueue: MTLCommandQueue! = { return self.device.makeCommandQueue() }()
    
    @IBOutlet var imageView: UIImageView!
   
    override var prefersStatusBarHidden: Bool { return true }
    
    //MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        do { scene = try Scene(device: device, width: imageSize, height: imageSize) } catch { fatalError(String(describing: error)) }

        imageView.frame = view.bounds

        timer = Timer.scheduledTimer(timeInterval: 1.0/60.0, target:self, selector: #selector(timerHandler), userInfo: nil, repeats:true)
    }
    
    //MARK: -

    var isBusy:Bool = false
    
    @objc func timerHandler() {
        if !isBusy {
            queue.async {
                self.isBusy = true
                self.scene.update()
                self.scene.rayTrace()
                
                DispatchQueue.main.async {
                    self.imageView.image = self.image(from: self.scene.texture)
                    self.isBusy = false
                }
            }
        }
    }
    
    // MARK: -
    // the fix is to turn off Metal API validation under Product -> Scheme -> Options
    
    func image(from texture: MTLTexture) -> UIImage {
        let bytesPerPixel:Int = 4
        let imageByteCount = texture.width * texture.height * bytesPerPixel
        let bytesPerRow = texture.width * bytesPerPixel
        var src = [UInt8](repeating: 0, count: Int(imageByteCount))
        
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        texture.getBytes(&src, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitsPerComponent = 8
        let context = CGContext(data: &src,
                                width: texture.width,
                                height: texture.height,
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo.rawValue)
        
        let dstImageFilter = context?.makeImage()
        return UIImage(cgImage: dstImageFilter!, scale: 0.0, orientation: UIImageOrientation.down)
    }
}
