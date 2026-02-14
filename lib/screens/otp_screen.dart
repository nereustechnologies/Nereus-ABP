// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:pin_code_fields/pin_code_fields.dart';
// import 'home_screen.dart';

// class OtpScreen extends StatefulWidget {
//   final String verificationId;
//   final String phoneNumber;

//   const OtpScreen({
//     super.key,
//     required this.verificationId,
//     required this.phoneNumber,
//   });

//   @override
//   State<OtpScreen> createState() => _OtpScreenState();
// }

// class _OtpScreenState extends State<OtpScreen> {
//   final TextEditingController _otpController = TextEditingController();
//   final FocusNode _otpFocusNode = FocusNode();

//   bool _loading = false;

//   void _handleOutsideTap() {
//     FocusScope.of(context).unfocus();
//   }

//   Future<void> _verifyOtp(String otp) async {
//     setState(() => _loading = true);

//     try {
//       final credential = PhoneAuthProvider.credential(
//         verificationId: widget.verificationId,
//         smsCode: otp,
//       );

//       await FirebaseAuth.instance.signInWithCredential(credential);

//       if (!mounted) return;

//       Navigator.of(context).pushReplacement(
//         MaterialPageRoute(builder: (_) => const HomeScreen()),
//       );
//     } catch (e) {
//       setState(() => _loading = false);

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Invalid OTP. Please try again.")),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _otpController.dispose();
//     _otpFocusNode.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final double fieldWidth = MediaQuery.of(context).size.width * 0.9;

//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: GestureDetector(
//         behavior: HitTestBehavior.translucent,
//         onTap: _handleOutsideTap,
//         child: Stack(
//           children: [
//             Center(
//               child: AnimatedSwitcher(
//                 duration: const Duration(milliseconds: 500),
//                 child: Image.asset(
//                   "assets/logo.png",
//                   key: const ValueKey('otp'),
//                   width: 180,
//                 ),
//               ),
//             ),

//             Align(
//               alignment: Alignment.bottomCenter,
//               child: Padding(
//                 padding: const EdgeInsets.only(bottom: 60),
//                 child: SizedBox(
//                   width: fieldWidth,
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text(
//                         "OTP sent to ${widget.phoneNumber}",
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 16,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),

//                       const SizedBox(height: 20),

//                       PinCodeTextField(
//                         appContext: context,
//                         length: 6,
//                         controller: _otpController,
//                         focusNode: _otpFocusNode,
//                         keyboardType: TextInputType.number,
//                         animationType: AnimationType.fade,
//                         pinTheme: PinTheme(
//                           shape: PinCodeFieldShape.box,
//                           borderRadius: BorderRadius.circular(8),
//                           fieldHeight: 70,
//                           fieldWidth: 50,
//                           inactiveFillColor: Colors.black12,
//                           selectedFillColor: Colors.black12,
//                           activeFillColor: Colors.black26,
//                           inactiveColor: Colors.white38,
//                           selectedColor: Colors.white,
//                           activeColor: Colors.white,
//                         ),
//                         textStyle: const TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 28,
//                           color: Colors.white,
//                           letterSpacing: 4,
//                         ),
//                         enableActiveFill: true,
//                         cursorColor: Colors.white,
//                         onChanged: (value) {},

//                         onCompleted: (value) {
//                           if (!_loading) {
//                             _verifyOtp(value);
//                           }
//                         },
//                       ),

//                       if (_loading) ...[
//                         const SizedBox(height: 18),
//                         const CircularProgressIndicator(
//                           color: Colors.white,
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
