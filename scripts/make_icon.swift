#!/usr/bin/env swift
// Gera o ícone do app no padrão do macOS a partir de uma arte quadrada "full-bleed".
//
// Uso: swift scripts/make_icon.swift <arte.png|jpg> <saida.png>
//
// A arte é reduzida para a área útil do grid de ícones da Apple (824×824 dentro de um
// canvas de 1024×1024), recortada em um retângulo de cantos arredondados e
// recebe uma sombra suave. O PNG resultante (1024×1024, com transparência) é a fonte
// usada pelo scripts/make-icon.sh para gerar o AppIcon.icns.

import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("uso: make_icon.swift <arte> <saida.png>\n".data(using: .utf8)!)
    exit(64)
}

let canvas: CGFloat = 1024
let body: CGFloat = 824                 // área útil do grid de ícones do macOS
let inset = (canvas - body) / 2         // 100 px de margem
let radius: CGFloat = 185.4             // raio padrão para um corpo de 824 px

guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let art = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    FileHandle.standardError.write("não foi possível ler \(args[1])\n".data(using: .utf8)!)
    exit(66)
}

guard let ctx = CGContext(data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8,
                          bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(70) }
ctx.interpolationQuality = .high

let rect = CGRect(x: inset, y: inset, width: body, height: body)
// Retângulo de cantos arredondados no raio do grid de ícones do macOS.
let shape = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).cgPath

// Sombra: desenha a forma preenchida com sombra, por baixo da arte.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28,
              color: CGColor(gray: 0, alpha: 0.35))
ctx.addPath(shape)
ctx.setFillColor(CGColor(gray: 0.1, alpha: 1))
ctx.fillPath()
ctx.restoreGState()

// Arte recortada na forma.
ctx.saveGState()
ctx.addPath(shape)
ctx.clip()
ctx.draw(art, in: rect)
// Borda interna sutil para destacar o ícone em fundos escuros.
ctx.addPath(shape)
ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.12))
ctx.setLineWidth(3)
ctx.strokePath()
ctx.restoreGState()

guard let out = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil) else { exit(73) }
CGImageDestinationAddImage(dest, out, nil)
guard CGImageDestinationFinalize(dest) else { exit(74) }
print("OK: \(args[2])")
