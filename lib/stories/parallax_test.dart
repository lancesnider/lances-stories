import 'package:flutter/material.dart';
import 'package:velocity_x/velocity_x.dart';
import 'package:lances_stories/util/parallax_tilt.dart';

class ParallaxTest extends StatelessWidget {
  const ParallaxTest({super.key});

  @override
  Widget build(BuildContext context) {
    const squareSize = 350.0;

    return Column(
      children: [
        Center(
          child: ParallaxTilt(
            // same feel as before; tweak or remove if you want linear
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, angles) {
              final x = angles.x; // matches your old xAngle
              final z = angles.z; // matches your old zAngle

              return [
                Transform(
                  origin: const Offset(squareSize / 2, squareSize / 2),
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.003)
                    ..rotateX(-z / 10)
                    ..rotateY(x / 10),
                  child: VxBox().rounded.width(300).height(300).make(),
                ),
                Transform(
                  origin: const Offset(150, 150),
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.002)
                    ..rotateX(-z / 10)
                    ..rotateY(x / 10),
                  child: VxBox()
                      .rounded
                      .withShadow([
                        BoxShadow(
                          color: const Color.fromARGB(106, 244, 117, 54),
                          blurRadius: 50,
                          spreadRadius: 5,
                          offset: Offset(x * 8, z * 8),
                        ),
                        const BoxShadow(
                          color: Color.fromARGB(116, 0, 0, 0),
                          blurRadius: 20,
                        ),
                      ])
                      .red400
                      .width(squareSize)
                      .height(squareSize)
                      .make(),
                ),
              ].zStack();
            },
          ),
        ),
      ],
    );
  }
}
