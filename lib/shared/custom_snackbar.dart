import 'package:flutter/material.dart';

void showCustomSnackbar(BuildContext context, String message, {bool success = true}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      content: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 17,
            fontFamily: 'Comfortaa',
            fontWeight: FontWeight.w700,
            color: Color(0xFF360638),
          ),
          textAlign: TextAlign.center,
        ),
      ),
      duration: Duration(seconds: 3),
    ),
  );
} 