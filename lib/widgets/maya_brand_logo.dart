import 'package:flutter/material.dart';



/// Maya platform brand on login — sized to fit without cropping.

class MayaBrandLogo extends StatelessWidget {

  const MayaBrandLogo({

    super.key,

    this.onSecretTap,

    this.height = 120,

  });



  static const assetPath = 'assets/branding/maya_brand.png';



  final VoidCallback? onSecretTap;

  final double height;



  @override

  Widget build(BuildContext context) {

    final maxWidth = MediaQuery.sizeOf(context).width - 48;

    final logoHeight = height.clamp(96.0, 160.0);



    return GestureDetector(

      onTap: onSecretTap,

      child: Container(

        width: double.infinity,

        constraints: BoxConstraints(

          maxHeight: logoHeight,

          minHeight: 96,

        ),

        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),

        decoration: BoxDecoration(

          borderRadius: BorderRadius.circular(20),

          color: Colors.white.withValues(alpha: 0.08),

          boxShadow: [

            BoxShadow(

              color: Colors.black.withValues(alpha: 0.1),

              blurRadius: 14,

              offset: const Offset(0, 6),

            ),

          ],

        ),

        clipBehavior: Clip.antiAlias,

        child: Image.asset(

          assetPath,

          width: maxWidth,

          height: logoHeight - 12,

          fit: BoxFit.contain,

          alignment: Alignment.center,

          errorBuilder: (_, _, _) => ColoredBox(

            color: Colors.indigo.shade700,

            child: Center(

              child: Icon(

                Icons.school,

                size: logoHeight * 0.28,

                color: Colors.white,

              ),

            ),

          ),

        ),

      ),

    );

  }

}


