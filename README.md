# sdl-gamepad-mapper

Ferramenta para fazer o controle **8BitDo Ultimate 2C Wired** funcionar no **macOS** em jogos e emuladores.

## O Problema

O macOS reconhece o 8BitDo Ultimate 2C como dispositivo USB e lê o HID (Human Interface Device) bruto normalmente, mas o framework **GCController** da Apple — responsável por identificar controles de jogo — ignora o dispositivo porque o VID/PID do 8BitDo não está na whitelist da Apple.

O resultado: o sistema "vê" o controle, mas nenhum jogo ou emulador reconhece ele como gamepad.

## A Solução

Este projeto lê os reports HID do controle via IOKit e gera um **mapeamento SDL2** (`SDL_GAMECONTROLLERCONFIG`) que ensina jogos baseados em SDL2/SDL3 a interpretar os botões e eixos corretamente.

O mapeamento é injetado como variável de ambiente no sistema. Jogos que usam SDL2 (a grande maioria dos jogos no Steam, emuladores como Ryujinx/RetroArch, e jogos indie) passam a reconhecer o 8BitDo como um gamepad padrão automaticamente.

## Requisitos

- macOS 13+ (Ventura ou superior)
- Swift 5.9+ (vem com Xcode Command Line Tools)
- 8BitDo Ultimate 2C conectado via USB

## Instalação

```bash
git clone https://github.com/jvniorgc/sdl-gamepad-mapper.git
cd fake-gamepad
swift build
```

## Uso Rápido

### 1. Gerar o mapeamento

```bash
.build/debug/fake-gamepad generate
```

Gera dois arquivos:
- `gamecontrollerdb_8bitdo.txt` — string de mapeamento SDL2
- `launch.sh` — script para lançar jogos com o mapeamento

### 2. Configurar no sistema

**Opção A — Global para todos os apps (recomendado):**

Roda uma vez e funciona para apps abertos pelo Finder, Dock e Spotlight:

```bash
launchctl setenv SDL_GAMECONTROLLERCONFIG "$(cat gamecontrollerdb_8bitdo.txt)"
```

Para persistir após reiniciar, copie o LaunchAgent para `~/Library/LaunchAgents/`:

```bash
mkdir -p ~/Library/LaunchAgents

cat > ~/Library/LaunchAgents/com.fakegamepad.sdl-env.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.fakegamepad.sdl-env</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>launchctl setenv SDL_GAMECONTROLLERCONFIG "$(cat $HOME/repos/personal/fake-gamepad/gamecontrollerdb_8bitdo.txt)"</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.fakegamepad.sdl-env.plist
```

**Opção B — Só no terminal:**

Adicione ao `~/.zshrc`:

```bash
export SDL_GAMECONTROLLERCONFIG='03000000c82d00001d30000001000000,8BitDo Ultimate 2C Wired Controller,a:b1,b:b0,x:b3,y:b4,leftshoulder:b6,rightshoulder:b7,back:b10,start:b11,guide:b12,leftstick:b13,rightstick:b14,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:a4,righttrigger:a5,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,platform:Mac OS X'
```

> ⚠️ Neste caso, apps abertos pelo Finder/Dock não herdam a variável. Para isso, use a Opção A.

**Opção C — Por jogo:**

```bash
./launch.sh /Applications/SeuJogo.app
```

### 3. Verificar

```bash
echo $SDL_GAMECONTROLLERCONFIG
```

Se imprimir a string de mapeamento, está funcionado.

## Comandos

| Comando | Descrição |
|---|---|
| `fake-gamepad generate` | Gera o mapeamento padrão (execução rápida, sem controle conectado) |
| `fake-gamepad map` | Modo interativo — pressione cada botão quando solicitado para criar um mapeamento personalizado |
| `fake-gamepad monitor` | Modo debug — exibe os reports HID brutos em tempo real |

## Botões estão errados?

O mapeamento padrão assume o layout DInput padrão do 8BitDo. Se algum botão estiver trocado:

```bash
.build/debug/fake-gamepad map
```

O modo interativo pede para pressionar cada botão e gera o mapeamento correto para o seu controle. Após gerar, atualize a variável de ambiente.

## Compatibilidade

| Tipo de Jogo | Funciona? | Notas |
|---|---|---|
| Jogos SDL2/SDL3 (maioria Steam/indie) | ✅ | Via `SDL_GAMECONTROLLERCONFIG` |
| Emuladores (Ryujinx, RetroArch, Dolphin) | ✅ | Usam SDL2 internamente |
| Steam (Big Picture) | ✅ | Steam também tem remapeamento próprio |
| Jogos GCController (Apple nativo) | ❌ | Requer virtual HID device (Xcode + Apple Developer Account) |

## Desinstalação

```bash
# Remover o LaunchAgent (se configurou a Opção A)
launchctl unload ~/Library/LaunchAgents/com.fakegamepad.sdl-env.plist
rm ~/Library/LaunchAgents/com.fakegamepad.sdl-env.plist

# Remover a variável da sessão atual
launchctl unsetenv SDL_GAMECONTROLLERCONFIG

# Remover do ~/.zshrc (se configurou a Opção B)
# Edite o arquivo e remova a linha SDL_GAMECONTROLLERCONFIG
```

## Como funciona

1. O 8BitDo Ultimate 2C se conecta via USB com VID `0x2DC8` e PID `0x301D`
2. O macOS expõe o dispositivo como HID com 15 botões, 1 hat switch, 4 eixos analógicos e 2 triggers
3. A ferramenta lê o HID Report Descriptor via IOKit e gera uma string de mapeamento no formato SDL2
4. A variável `SDL_GAMECONTROLLERCONFIG` injeta esse mapeamento nos jogos, que passam a reconhecer o dispositivo como gamepad padrão
