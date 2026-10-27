import SwiftUI

/// La pantalla y las teclas de la calculadora, como la de Apple: redondas en la básica y, en la
/// científica, con seis columnas más a la izquierda. Siempre en oscuro, como la de Apple.
struct TecladoCalculadora: View {
    @Binding var calculadora: Calculadora
    @Binding var cientifica: Bool

    /// Las medidas de cada modo; con ellas se calcula también el tamaño de la ventana.
    struct Medidas {
        let ancho: CGFloat
        let alto: CGFloat
        let separacion: CGFloat
        let altoPantalla: CGFloat
        let letra: CGFloat
        let letraPantalla: CGFloat

        static func de(cientifica: Bool) -> Medidas {
            if cientifica {
                return Medidas(ancho: 44, alto: 36, separacion: 6, altoPantalla: 84, letra: 17, letraPantalla: 44)
            }
            return Medidas(ancho: 50, alto: 50, separacion: 9, altoPantalla: 96, letra: 24, letraPantalla: 56)
        }
    }

    static let margen: CGFloat = 14
    static let altoCabecera: CGFloat = 28
    static let naranja = Color(red: 1, green: 0.62, blue: 0.04)

    /// El tamaño de la ventana entera: cabecera, pantalla y cinco filas de teclas.
    static func tamaño(cientifica: Bool) -> CGSize {
        let medidas = Medidas.de(cientifica: cientifica)
        let columnas: CGFloat = cientifica ? 10 : 4
        let ancho = columnas * medidas.ancho + (columnas - 1) * medidas.separacion + margen * 2
        let teclas = 5 * medidas.alto + 4 * medidas.separacion
        let alto = margen * 2 + altoCabecera + medidas.altoPantalla + 10 + teclas
        return CGSize(width: ancho, height: alto)
    }

    private var medidas: Medidas {
        Medidas.de(cientifica: cientifica)
    }

    var body: some View {
        VStack(spacing: 0) {
            pantalla
            Spacer(minLength: 10)
            teclas
        }
    }

    private var pantalla: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 6) {
                if calculadora.enRadianes { Indicador(texto: "Rad") }
                if calculadora.hayMemoria { Indicador(texto: "M") }
                Spacer(minLength: 0)
                Text(calculadora.cuentaAnterior)
                    .font(.system(size: 18))
                    .foregroundStyle(Color(white: 0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(height: 22)
            Text(calculadora.pantalla)
                .font(.system(size: medidas.letraPantalla, weight: .light))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = calculadora.pantalla
                    } label: {
                        Label("Copiar", systemImage: "doc.on.doc")
                    }
                }
        }
        .frame(height: medidas.altoPantalla, alignment: .bottom)
    }

    private var teclas: some View {
        let basicas = filasBasicas
        let cientificas = filasCientificas
        return VStack(spacing: medidas.separacion) {
            ForEach(0..<5, id: \.self) { fila in
                HStack(spacing: medidas.separacion) {
                    if cientifica {
                        ForEach(cientificas[fila].indices, id: \.self) { columna in
                            boton(cientificas[fila][columna])
                        }
                    }
                    ForEach(basicas[fila].indices, id: \.self) { columna in
                        boton(basicas[fila][columna])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func boton(_ tecla: TeclaCalculadora) -> some View {
        if let accion = tecla.accion {
            Button {
                calculadora.pulsar(accion)
            } label: {
                CaraTecla(tecla: tecla, medidas: medidas, activa: accion == .segunda && calculadora.segunda)
            }
            .buttonStyle(TeclaPulsada())
        } else {
            // Como en la de Apple: abajo a la izquierda se elige entre básica y científica.
            Menu {
                Picker("Calculadora", selection: $cientifica) {
                    Text("Básica").tag(false)
                    Text("Científica").tag(true)
                }
            } label: {
                CaraTecla(tecla: tecla, medidas: medidas, activa: false)
            }
            .accessibilityLabel("Básica o científica")
        }
    }
}

/// Una tecla: lo que pone, su color y lo que hace (nil: la de cambiar entre básica y científica).
struct TeclaCalculadora {
    enum Estilo {
        case cifra, funcion, operador, cientifica
    }

    let etiqueta: String
    let estilo: Estilo
    let accion: Calculadora.Tecla?
}

/// Las filas de teclas, en el orden de la de Apple.
extension TecladoCalculadora {
    var filasBasicas: [[TeclaCalculadora]] {
        let fila1: [TeclaCalculadora] = [funcion(calculadora.etiquetaBorrar, .borrar), funcion("+/−", .cambiarSigno),
                                         funcion("%", .posfijo(.porcentaje)), operador("÷", .operador(.division))]
        let fila2: [TeclaCalculadora] = [cifra(7), cifra(8), cifra(9), operador("×", .operador(.producto))]
        let fila3: [TeclaCalculadora] = [cifra(4), cifra(5), cifra(6), operador("−", .operador(.resta))]
        let fila4: [TeclaCalculadora] = [cifra(1), cifra(2), cifra(3), operador("+", .operador(.suma))]
        let fila5: [TeclaCalculadora] = [TeclaCalculadora(etiqueta: "", estilo: .cifra, accion: nil), cifra(0),
                                         TeclaCalculadora(etiqueta: ",", estilo: .cifra, accion: .coma), operador("=", .igual)]
        return [fila1, fila2, fila3, fila4, fila5]
    }

    /// Con 2nd, las teclas que tienen inversa la enseñan (sin → sin⁻¹, ln → logᵧ…).
    var filasCientificas: [[TeclaCalculadora]] {
        let inv = calculadora.segunda
        let fila1: [TeclaCalculadora] = [ciencia("(", .abre), ciencia(")", .cierra), ciencia("mc", .memoria(.borrar)),
                                         ciencia("m+", .memoria(.sumar)), ciencia("m−", .memoria(.restar)),
                                         ciencia("mr", .memoria(.recuperar))]
        let fila2: [TeclaCalculadora] = [ciencia("2nd", .segunda), ciencia("x²", .posfijo(.cuadrado)),
                                         ciencia("x³", .posfijo(.cubo)), ciencia("xʸ", .operador(.potencia)),
                                         inv ? ciencia("yˣ", .operador(.potenciaInversa)) : ciencia("eˣ", .funcion(.exponencial)),
                                         inv ? ciencia("2ˣ", .funcion(.dosALa)) : ciencia("10ˣ", .funcion(.diezALa))]
        let fila3: [TeclaCalculadora] = [ciencia("1/x", .posfijo(.inverso)), ciencia("²√x", .funcion(.raizCuadrada)),
                                         ciencia("³√x", .funcion(.raizCubica)), ciencia("ʸ√x", .operador(.raiz)),
                                         inv ? ciencia("logᵧ", .operador(.logaritmo)) : ciencia("ln", .funcion(.ln)),
                                         inv ? ciencia("log₂", .funcion(.log2)) : ciencia("log₁₀", .funcion(.log10))]
        let fila4: [TeclaCalculadora] = [ciencia("x!", .posfijo(.factorial)),
                                         inv ? ciencia("sin⁻¹", .funcion(.arcoseno)) : ciencia("sin", .funcion(.seno)),
                                         inv ? ciencia("cos⁻¹", .funcion(.arcocoseno)) : ciencia("cos", .funcion(.coseno)),
                                         inv ? ciencia("tan⁻¹", .funcion(.arcotangente)) : ciencia("tan", .funcion(.tangente)),
                                         ciencia("e", .constante(.e)), ciencia("EE", .operador(.exponente))]
        let fila5: [TeclaCalculadora] = [ciencia(calculadora.enRadianes ? "Deg" : "Rad", .radianes),
                                         inv ? ciencia("sinh⁻¹", .funcion(.arcosenoH)) : ciencia("sinh", .funcion(.senoH)),
                                         inv ? ciencia("cosh⁻¹", .funcion(.arcocosenoH)) : ciencia("cosh", .funcion(.cosenoH)),
                                         inv ? ciencia("tanh⁻¹", .funcion(.arcotangenteH)) : ciencia("tanh", .funcion(.tangenteH)),
                                         ciencia("π", .constante(.pi)), ciencia("Rand", .aleatorio)]
        return [fila1, fila2, fila3, fila4, fila5]
    }

    private func cifra(_ numero: Int) -> TeclaCalculadora {
        TeclaCalculadora(etiqueta: "\(numero)", estilo: .cifra, accion: .digito(numero))
    }

    private func funcion(_ etiqueta: String, _ accion: Calculadora.Tecla) -> TeclaCalculadora {
        TeclaCalculadora(etiqueta: etiqueta, estilo: .funcion, accion: accion)
    }

    private func operador(_ etiqueta: String, _ accion: Calculadora.Tecla) -> TeclaCalculadora {
        TeclaCalculadora(etiqueta: etiqueta, estilo: .operador, accion: accion)
    }

    private func ciencia(_ etiqueta: String, _ accion: Calculadora.Tecla) -> TeclaCalculadora {
        TeclaCalculadora(etiqueta: etiqueta, estilo: .cientifica, accion: accion)
    }
}

/// Cómo se ve una tecla: una cápsula (redonda en la básica) con los colores de la de Apple.
private struct CaraTecla: View {
    let tecla: TeclaCalculadora
    let medidas: TecladoCalculadora.Medidas
    let activa: Bool

    var body: some View {
        rotulo
            .foregroundStyle(.white)
            .frame(width: medidas.ancho, height: medidas.alto)
            .background(Capsule().fill(fondo))
            .contentShape(Capsule())
    }

    @ViewBuilder
    private var rotulo: some View {
        if tecla.accion == nil {
            Image(systemName: "plus.forwardslash.minus")
                .font(.system(size: medidas.letra * 0.8, weight: .medium))
        } else if tecla.etiqueta == "⌫" {
            Image(systemName: "delete.left")
                .font(.system(size: medidas.letra * 0.8, weight: .medium))
        } else {
            Text(tecla.etiqueta)
                .font(fuente)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 2)
        }
    }

    private var fuente: Font {
        switch tecla.estilo {
        case .cientifica: return .system(size: medidas.letra * 0.8)
        case .operador: return .system(size: medidas.letra + 6, weight: .medium)
        case .funcion: return .system(size: medidas.letra, weight: .medium)
        case .cifra: return .system(size: medidas.letra + 2)
        }
    }

    private var fondo: Color {
        if activa { return Color(white: 0.6) }
        switch tecla.estilo {
        case .cifra: return Color(white: 0.2)
        case .funcion: return Color(white: 0.36)
        case .operador: return TecladoCalculadora.naranja
        case .cientifica: return Color(white: 0.13)
        }
    }
}

/// Al pulsar, la tecla se aclara un momento, como en la de Apple.
private struct TeclaPulsada: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? 0.3 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// «Rad» y «M» en la pantalla, como en la de Apple.
private struct Indicador: View {
    let texto: String

    var body: some View {
        Text(texto)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(white: 0.75))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().stroke(Color(white: 0.45)))
    }
}
