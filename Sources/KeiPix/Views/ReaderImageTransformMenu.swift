import SwiftUI

struct ReaderImageTransformMenu: View {
    @Binding var transform: ReaderImageTransform

    var body: some View {
        Menu {
            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    transform.rotateLeft()
                }
            } label: {
                Label(L10n.rotateLeft, systemImage: "rotate.left")
            }

            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    transform.rotateRight()
                }
            } label: {
                Label(L10n.rotateRight, systemImage: "rotate.right")
            }

            Divider()

            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    transform.flipHorizontal()
                }
            } label: {
                Label(
                    L10n.flipHorizontal,
                    systemImage: transform.isFlippedHorizontally
                        ? "arrow.left.and.right.righttriangle.left.righttriangle.right.fill"
                        : "arrow.left.and.right.righttriangle.left.righttriangle.right"
                )
            }

            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    transform.flipVertical()
                }
            } label: {
                Label(
                    L10n.flipVertical,
                    systemImage: transform.isFlippedVertically
                        ? "arrow.up.and.down.righttriangle.up.righttriangle.down.fill"
                        : "arrow.up.and.down.righttriangle.up.righttriangle.down"
                )
            }

            Divider()

            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    transform.reset()
                }
            } label: {
                Label(L10n.resetTransform, systemImage: "arrow.counterclockwise")
            }
            .disabled(transform.isIdentity)
        } label: {
            Label(L10n.imageTransform, systemImage: "crop.rotate")
        }
        .accessibilityLabel(L10n.imageTransform)
        .help(L10n.imageTransform)
    }
}
