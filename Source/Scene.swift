import Metal
import simd

public class Scene {
    let texture: MTLTexture
    let pipeline: MTLComputePipelineState
    let threads: MTLSize
    let groups: MTLSize
    lazy var device: MTLDevice! = MTLCreateSystemDefaultDevice()
    lazy var commandQueue: MTLCommandQueue! = { return self.device.makeCommandQueue() }()
    
    var p = Param()
    
    public init(device: MTLDevice, width: Int, height: Int) throws {
        let library: MTLLibrary = try device.makeDefaultLibrary(bundle: Bundle(for: type(of: self)))
        let constantValues: MTLFunctionConstantValues = MTLFunctionConstantValues()
        pipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "trace",
                                                                                      constantValues: constantValues))
        threads = MTLSize(width: pipeline.threadExecutionWidth, height: 1, depth: 1)
        groups = MTLSize(width: (width-1)/threads.width+1, height: (height-1)/threads.height+1, depth: 1)
        
        let descriptor: MTLTextureDescriptor = .texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                    width: groups.width * threads.width,
                                                                    height: groups.height * threads.height,
                                                                    mipmapped: false)
        descriptor.usage = [.shaderWrite, .shaderRead]
        guard let mtltexture: MTLTexture = device.makeTexture(descriptor: descriptor) else { throw NSError(domain: #function, code: #line, userInfo: nil) }
        texture = mtltexture
        
        initializeObjects()
    }
    
    //MARK: -
    
    var angle:Float = 0
    
    func initializeObjects() {
        setObject(&p,0,Object(kind:KIND_PLANE,   p1:float3(0, -1, 0), p2:float3(0, 1, 0), p3:float3(), color:float3(0,1,0)))
        setObject(&p,1,Object(kind:KIND_TRIANGLE,p1:float3(0, 1, 2.5), p2:float3(-1.5, 0.1, 2.5), p3:float3( 1.5, 0.1, 2.9), color:float3(1,1,0)))
        setObject(&p,2,Object(kind:KIND_SPHERE,  p1:float3(0, 0.3, 1), p2:float3(0.3), p3:float3(), color:float3(1,0,1)))
        setObject(&p,3,Object(kind:KIND_SPHERE,  p1:float3(-0.5, 0.5, 1), p2:float3(0.4), p3:float3(), color:float3(1,1,0.3)))
        setObject(&p,4,Object(kind:KIND_SPHERE,  p1:float3( 0.5, 1.0, 1.5), p2:float3(0.5), p3:float3(), color:float3(1,0.3,0.7)))
        setObject(&p,5,Object(kind:KIND_SPHERE,  p1:float3(0.5 + cosf(angle)*2, 0.5, 2.5 + sinf(angle)*2), p2:float3(0.3), p3:float3(), color:float3(0,0.3,0.3)))
        p.count = Int32(6)
    }
    
    //MARK: -
    
    func update() {
        angle += 0.01
        setObject(&p,5,Object(kind:KIND_SPHERE,  p1:float3(0.5 + cosf(angle)*2, 0.5, 2.5 + sinf(angle)*2), p2:float3(0.3), p3:float3(), color:float3(0,0.3,0.3)))
        
        p.light = float3(cosf(angle)*10,0.5,sinf(angle)*10)
    }
    
    //MARK: -
    
    func rayTrace() {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        assert( commandBuffer.device === texture.device )
        assert( commandBuffer.device === pipeline.device )
        guard let encoder: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setBytes(&p, length: MemoryLayout<Param>.size, index: 0)
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
