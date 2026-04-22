import Foundation
import IOKit.hid

// MARK: - Fake Gamepad — SDL2 Controller Mapping Tool
// Reads HID input from 8BitDo Ultimate 2C and generates SDL2 mapping

let version = "0.2.0"

func printBanner() {
    print("""
    ╔═══════════════════════════════════════════════════╗
    ║   Fake Gamepad v\(version)                            ║
    ║   SDL2 Mapping Tool for 8BitDo Ultimate 2C       ║
    ╚═══════════════════════════════════════════════════╝
    """)
}

// MARK: - Mode selection

enum Mode: String {
    case interactive = "map"
    case monitor = "monitor"
    case generate = "generate"
}

func printUsage() {
    print("""
    Usage: fake-gamepad [command]
    
    Commands:
      generate   Generate SDL2 mapping with default button layout (quick)
      map        Interactive mapping — press each button when prompted
      monitor    Monitor raw HID input (debug mode)
    
    No command defaults to 'generate'.
    """)
}

let args = CommandLine.arguments
let mode: Mode = {
    if args.count > 1 {
        if let m = Mode(rawValue: args[1]) { return m }
        if args[1] == "--help" || args[1] == "-h" {
            printBanner()
            printUsage()
            exit(0)
        }
    }
    return .generate
}()

printBanner()

// MARK: - Generate GUID

let guid = SDLMappingGenerator.generateGUID(
    vendorID: PhysicalController.vendorID,
    productID: PhysicalController.productID
)

// MARK: - Quick Generate Mode

if mode == .generate {
    print("📋 Generating SDL2 mapping for 8BitDo Ultimate 2C...\n")
    
    let (buttons, axes) = SDLMappingGenerator.default8BitDoMapping()
    let mapping = SDLMappingGenerator.generateMapping(
        guid: guid,
        name: "8BitDo Ultimate 2C Wired Controller",
        buttons: buttons,
        axes: axes
    )
    
    print("SDL2 GUID: \(guid)")
    print()
    print("═══ SDL_GAMECONTROLLERCONFIG ═══")
    print(mapping)
    print("════════════════════════════════\n")
    
    // Save to file
    let configDir = FileManager.default.currentDirectoryPath
    let mappingFile = "\(configDir)/gamecontrollerdb_8bitdo.txt"
    try? mapping.write(toFile: mappingFile, atomically: true, encoding: .utf8)
    print("💾 Mapping saved to: \(mappingFile)")
    
    // Generate launch script
    let launchScript = """
    #!/bin/bash
    # Launch any game/app with 8BitDo Ultimate 2C controller support
    # Usage: ./launch.sh /path/to/game.app
    #    or: ./launch.sh steam://open/bigpicture
    
    export SDL_GAMECONTROLLERCONFIG="\(mapping)"
    
    if [ -z "$1" ]; then
        echo "Usage: ./launch.sh <app-path-or-url>"
        echo ""
        echo "Examples:"
        echo "  ./launch.sh /Applications/SomeGame.app"
        echo "  ./launch.sh steam://open/bigpicture"
        echo ""
        echo "Or set the environment variable globally:"
        echo "  export SDL_GAMECONTROLLERCONFIG='$SDL_GAMECONTROLLERCONFIG'"
        exit 1
    fi
    
    TARGET="$1"
    shift
    
    if [[ "$TARGET" == *"://"* ]]; then
        open "$TARGET"
    elif [[ "$TARGET" == *.app ]]; then
        open -a "$TARGET" --args "$@"
    else
        "$TARGET" "$@"
    fi
    """
    
    let launchFile = "\(configDir)/launch.sh"
    try? launchScript.write(toFile: launchFile, atomically: true, encoding: .utf8)
    chmod(launchFile)
    print("💾 Launch script saved to: \(launchFile)")
    
    print("""
    
    🎮 Como usar:
    
      1. Via script de lançamento:
         ./launch.sh /Applications/SeuJogo.app
    
      2. Via variável de ambiente (sessão inteira do terminal):
         export SDL_GAMECONTROLLERCONFIG='\(mapping)'
    
      3. No ~/.zshrc (permanente para todos os terminais):
         Copie a linha SDL_GAMECONTROLLERCONFIG acima e adicione ao seu ~/.zshrc
    
      4. No Steam: vá em Settings > Controller e adicione o mapeamento
    
    ⚠️  Isso funciona para jogos baseados em SDL2/SDL3.
        Para jogos que usam GCController (Apple nativo), é necessário
        a abordagem de virtual HID device (requer Xcode + Developer Account).
    
    💡 Se os botões estiverem errados, rode: fake-gamepad map
    """)
    
    exit(0)
}

// MARK: - Monitor / Interactive modes require the controller

let controller = PhysicalController()
var previousReport = PhysicalController.Report.neutral
var connected = false

controller.onConnect = {
    connected = true
    print("🎮 8BitDo Ultimate 2C conectado!\n")
}

controller.onDisconnect = {
    connected = false
    print("\n🎮 Controle desconectado")
}

guard controller.start() else {
    print("❌ Falha ao iniciar o HID Manager")
    exit(1)
}

print("⏳ Aguardando conexão do 8BitDo Ultimate 2C...")
print("   (VID: 0x\(String(PhysicalController.vendorID, radix: 16)), PID: 0x\(String(PhysicalController.productID, radix: 16)))\n")

// MARK: - Monitor Mode

if mode == .monitor {
    print("📊 Modo monitor — mostrando HID bruto. Ctrl+C para sair.\n")
    
    var reportCount: UInt64 = 0
    
    controller.onReport = { report in
        reportCount += 1
        let btns = String(report.buttons, radix: 2)
            .padding(toLength: 15, withPad: "0", startingAt: 0)
        // Reverse for display (bit 0 on left)
        let btnDisplay = String(btns.reversed())
        print(String(format: "\r#%-6d Btn:[%@] Hat:%X LX:%-3d LY:%-3d RX:%-3d RY:%-3d LT:%-3d RT:%-3d",
                     reportCount, btnDisplay, report.hatSwitch,
                     report.leftStickX, report.leftStickY,
                     report.rightStickX, report.rightStickY,
                     report.leftTrigger, report.rightTrigger),
              terminator: "")
        fflush(stdout)
    }
    
    signal(SIGINT) { _ in print("\n"); exit(0) }
    RunLoop.main.run()
}

// MARK: - Interactive Mapping Mode

if mode == .interactive {
    print("🗺️  Modo mapeamento interativo")
    print("   Pressione cada botão quando solicitado.\n")
    
    let sdlButtons: [(String, String)] = [
        ("a", "A (botão de baixo / South)"),
        ("b", "B (botão da direita / East)"),
        ("x", "X (botão da esquerda / West)"),
        ("y", "Y (botão de cima / North)"),
        ("leftshoulder", "LB (Left Bumper)"),
        ("rightshoulder", "RB (Right Bumper)"),
        ("back", "Select / Back"),
        ("start", "Start"),
        ("guide", "Home / Guide"),
        ("leftstick", "L3 (pressionar analógico esquerdo)"),
        ("rightstick", "R3 (pressionar analógico direito)"),
    ]
    
    var mapping: [String: Int] = [:]
    var currentButtonIndex = 0
    var waitingForRelease = false
    
    func promptNext() {
        if currentButtonIndex >= sdlButtons.count {
            finishMapping()
            return
        }
        let (_, desc) = sdlButtons[currentButtonIndex]
        print("  👉 Pressione: \(desc)")
    }
    
    func finishMapping() {
        print("\n✅ Mapeamento completo!\n")
        
        let buttons = SDLMappingGenerator.ButtonMapping(
            a: mapping["a"], b: mapping["b"],
            x: mapping["x"], y: mapping["y"],
            leftshoulder: mapping["leftshoulder"],
            rightshoulder: mapping["rightshoulder"],
            back: mapping["back"], start: mapping["start"],
            guide: mapping["guide"],
            leftstick: mapping["leftstick"],
            rightstick: mapping["rightstick"]
        )
        
        let axes = SDLMappingGenerator.AxisMapping(
            leftx: 0, lefty: 1, rightx: 2, righty: 3,
            lefttrigger: 4, righttrigger: 5
        )
        
        let result = SDLMappingGenerator.generateMapping(
            guid: guid,
            name: "8BitDo Ultimate 2C Wired Controller",
            buttons: buttons,
            axes: axes
        )
        
        print("═══ SDL_GAMECONTROLLERCONFIG ═══")
        print(result)
        print("════════════════════════════════\n")
        
        let configDir = FileManager.default.currentDirectoryPath
        let mappingFile = "\(configDir)/gamecontrollerdb_8bitdo.txt"
        try? result.write(toFile: mappingFile, atomically: true, encoding: .utf8)
        print("💾 Salvo em: \(mappingFile)")
        
        exit(0)
    }
    
    // Wait for controller connection before starting
    var started = false
    controller.onConnect = {
        connected = true
        print("🎮 8BitDo Ultimate 2C conectado!\n")
        if !started {
            started = true
            print("Vamos mapear os botões. Solte tudo primeiro...\n")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                promptNext()
            }
        }
    }
    
    controller.onReport = { report in
        guard started else { return }
        
        if waitingForRelease {
            if report.buttons == 0 {
                waitingForRelease = false
                currentButtonIndex += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    promptNext()
                }
            }
            return
        }
        
        // Detect new button press
        let newButtons = report.buttons & ~previousReport.buttons
        if newButtons != 0 {
            // Find first new button
            for i in 0..<15 {
                if newButtons & (1 << i) != 0 {
                    let (name, desc) = sdlButtons[currentButtonIndex]
                    mapping[name] = i
                    print("     ✓ \(desc) → button \(i)")
                    waitingForRelease = true
                    break
                }
            }
        }
        
        previousReport = report
    }
    
    signal(SIGINT) { _ in print("\n"); exit(0) }
    RunLoop.main.run()
}

// MARK: - Helpers

func chmod(_ path: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/chmod")
    process.arguments = ["+x", path]
    try? process.run()
    process.waitUntilExit()
}
