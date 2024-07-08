import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _forgotUsernameController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  bool _isCreatingAccount = false;
  bool _isForgotPassword = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('username');
    String? password = prefs.getString('password');
    if (username != null && password != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (context) => ReminderScreen(username: username)),
      );
    }
  }

  void _toggleForm() {
    setState(() {
      _isCreatingAccount = !_isCreatingAccount;
      _isForgotPassword = false;
      _clearTextFields();
    });
  }

  void _toggleForgotPassword() {
    setState(() {
      _isForgotPassword = !_isForgotPassword;
      _isCreatingAccount = false;
      _clearTextFields();
    });
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final username = _usernameController.text;
      final password = _passwordController.text;

      final storedPassword = await _getPasswordForUsername(username);
      if (storedPassword == null) {
        _showDialog('Username not found', 'Error');
      } else if (storedPassword != password) {
        _showDialog('Wrong password', 'Error');
      } else {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setString('username', username);
        prefs.setString('password', password);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) => ReminderScreen(username: username)),
        );
      }
    }
  }

  Future<void> _createAccount() async {
    if (_formKey.currentState!.validate()) {
      final username = _usernameController.text;
      final password = _passwordController.text;

      if (await _getPasswordForUsername(username) != null) {
        _showDialog('Username already exists', 'Error');
      } else {
        await _savePasswordForUsername(username, password);
        _showDialog('Account created successfully', 'Success', _toggleForm);
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      final username = _forgotUsernameController.text;
      final newPassword = _newPasswordController.text;

      if (await _getPasswordForUsername(username) != null) {
        await _savePasswordForUsername(username, newPassword);
        _showDialog(
            'Password reset successfully', 'Success', _toggleForgotPassword);
      } else {
        _showDialog('Username not found', 'Error');
      }
    }
  }

  Future<String?> _getPasswordForUsername(String username) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('password_$username');
  }

  Future<void> _savePasswordForUsername(
      String username, String password) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('password_$username', password);
  }

  void _showDialog(String message, String title, [VoidCallback? onOkPressed]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearTextFields();
                if (onOkPressed != null) {
                  onOkPressed();
                }
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _clearTextFields() {
    _usernameController.clear();
    _passwordController.clear();
    _forgotUsernameController.clear();
    _newPasswordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Medicine Reminder')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isForgotPassword && !_isCreatingAccount) ...[
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(labelText: 'Username'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your username';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _login,
                  child: Text('Login'),
                ),
                TextButton(
                  onPressed: _toggleForm,
                  child: Text('Create an account'),
                ),
                TextButton(
                  onPressed: _toggleForgotPassword,
                  child: Text('Forgot Password?'),
                ),
              ],
              if (_isCreatingAccount) ...[
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(labelText: 'Username'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your username';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _createAccount,
                  child: Text('Create Account'),
                ),
                TextButton(
                  onPressed: _toggleForm,
                  child: Text('Already have an account? Login'),
                ),
              ],
              if (_isForgotPassword) ...[
                TextFormField(
                  controller: _forgotUsernameController,
                  decoration: InputDecoration(labelText: 'Username'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your username';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _newPasswordController,
                  decoration: InputDecoration(labelText: 'New Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your new password';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _resetPassword,
                  child: Text('Reset Password'),
                ),
                TextButton(
                  onPressed: _toggleForgotPassword,
                  child: Text('Back to Login'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
