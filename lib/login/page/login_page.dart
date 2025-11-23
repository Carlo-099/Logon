import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logon/home/page/home_page.dart';
import 'package:logon/register/page/register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailcontroler = TextEditingController();
  final passwordcontroler = TextEditingController();

Future<void> login() async{
  try{
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: emailcontroler.text.trim(), 
      password: passwordcontroler.text.trim()
    );
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));     

  } catch (e) {
    String errorMessage = "Login failed. Please try again.";
    
    if (e is FirebaseAuthException) {
      if (e.code == 'user-not-found') {
        errorMessage = "No user found for that email.";
      } else if (e.code == 'wrong-password') {
        errorMessage = "Wrong password provided.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "The email address is not valid.";
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  @override
  void dispose() {
    emailcontroler.dispose();
    passwordcontroler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    appBar:AppBar(title: Text('Login'),),
    body: Padding(
      padding: const EdgeInsets.only(left: 25, right: 20 ),
      child: Column(
        children: [
          TextField(
            controller: emailcontroler,
            decoration: InputDecoration(
              label: Text("Email"),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25)
              )
            ),
            
          ),
          SizedBox(height: 25,),
          TextField(
            controller: passwordcontroler,
            obscureText: true,
            decoration: InputDecoration(
              label: Text("Password"),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25)
              )
            ),
            
          ),
          SizedBox(height: 25,),
          InkWell(
            onTap: login,
            child: Container(
              height: 40,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(25)
              ),
              
              child: Center(child: Text("Login Na!", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Don't have an account? "),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterPage()),
                  );
                },
                child: const Text(
                  "Create an account",
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}