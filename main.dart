// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, avoid_print, deprecated_member_use, prefer_typing_uninitialized_variables

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:ui' as ui;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voter App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
      routes: {
        '/register': (context) => const RegisterScreen(),
        '/login': (context) => const LoginScreen(),
        '/vote': (context) => const VoteScreen(),
        '/results': (context) => const ResultsScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voter App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text('Register'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _countryController = TextEditingController();
  final _addressController = TextEditingController();
  final _codeController = TextEditingController();
  String? _gender;
  String? _state;
  Uint8List? _idCardBytes;
  String? _idCardFileName;
  html.VideoElement? _webcamVideoElement;
  Uint8List? _imageBytes;
  String _step = 'request_code';
  bool _isLoading = false;
  bool _isWebcamInitialized = false;

  final List<String> _states = [
    'Afar',
    'Amhara',
    'Benishangul-Gumuz',
    'Gambela',
    'Harari',
    'Oromia',
    'Sidama',
    'Somali',
    'South West Ethiopia Peoples\' Region',
    'Southern Nations, Nationalities, and Peoples\' Region (SNNPR)',
    'Tigray',
    'Addis Ababa',
    'Dire Dawa',
  ];

  @override
  void initState() {
    super.initState();
    _countryController.text = 'Ethiopia';
    if (_step == 'verify_code') {
      _initializeWebcam();
    }
  }

  void _initializeWebcam() async {
    try {
      _webcamVideoElement = html.VideoElement();
      final stream = await html.window.navigator.getUserMedia(video: true);
      _webcamVideoElement!.srcObject = stream;
      await _webcamVideoElement!.play();
      setState(() {
        _isWebcamInitialized = true;
      });
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        'webcamVideoElement-$hashCode',
        (int viewId) => _webcamVideoElement!,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error accessing webcam: $e')));
    }
  }

  @override
  void dispose() {
    if (_webcamVideoElement != null) {
      final tracks = _webcamVideoElement!.srcObject?.getTracks();
      tracks?.forEach((track) => track.stop());
      _webcamVideoElement!.srcObject = null;
      _webcamVideoElement = null;
    }
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _countryController.dispose();
    _addressController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pickIdCard() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No image selected')));
        return;
      }

      final bytes = await pickedFile.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID card image must be under 5MB')),
        );
        return;
      }
      setState(() {
        _idCardBytes = bytes;
        _idCardFileName = pickedFile.name;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID card selected successfully')),
      );
    } catch (e) {
      print('Error picking ID card: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking ID card: $e')));
    }
  }

  Future<void> _takePicture() async {
    try {
      if (!_isWebcamInitialized || _webcamVideoElement == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Webcam not initialized')));
        return;
      }
      final canvas = html.CanvasElement(
        width: _webcamVideoElement!.videoWidth,
        height: _webcamVideoElement!.videoHeight,
      );
      canvas.context2D.drawImage(_webcamVideoElement!, 0, 0);
      final dataUrl = canvas.toDataUrl('image/jpeg', 0.8);
      final bytes = base64Decode(dataUrl.split(',').last);
      if (bytes.length > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Facial image must be under 5MB')),
        );
        return;
      }
      setState(() {
        _imageBytes = bytes;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the errors in the form')),
      );
      return;
    }
    if (_idCardBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a National ID card')),
      );
      return;
    }
    if (_step == 'verify_code' && _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture a facial image')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final url = Uri.parse('http://127.0.0.1:5000/register');
    final request =
        http.MultipartRequest('POST', url)
          ..headers['Accept'] = 'application/json'
          ..headers['Content-Type'] = 'multipart/form-data';

    request.fields.addAll({
      'step': _step,
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
      'phone_number': _phoneController.text.trim(),
      'date_of_birth': _dobController.text,
      'gender': _gender ?? '',
      'state': _state ?? '',
      'country': _countryController.text.trim(),
      'address': _addressController.text.trim(),
    });

    if (_step == 'verify_code') {
      request.fields['code'] = _codeController.text.trim();
    }

    try {
      if (_idCardBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'id_card',
            _idCardBytes!,
            filename: _idCardFileName ?? 'id_card.jpg',
          ),
        );
      }
      if (_step == 'verify_code' && _imageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            _imageBytes!,
            filename: 'facial_image.jpg',
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error preparing files: $e')));
      return;
    }

    try {
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (!response.statusCode.toString().startsWith('2')) {
        throw Exception(data['message'] ?? 'Unknown error');
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(data['message'])));

      if (response.statusCode == 200 &&
          data['success'] &&
          _step == 'request_code') {
        setState(() {
          _step = 'verify_code';
          _initializeWebcam();
        });
      } else if (response.statusCode == 201 && data['success']) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                readOnly: _step == 'verify_code',
                validator:
                    (value) =>
                        value == null ||
                                !RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(value)
                            ? 'Invalid email format'
                            : null,
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                readOnly: _step == 'verify_code',
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Name is required'
                            : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                readOnly: _step == 'verify_code',
                validator:
                    (value) =>
                        value == null || value.length < 8
                            ? 'Password must be 8+ characters'
                            : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                readOnly: _step == 'verify_code',
                validator:
                    (value) =>
                        value != null && value.length > 20
                            ? 'Phone number too long'
                            : null,
              ),
              TextFormField(
                controller: _dobController,
                decoration: const InputDecoration(labelText: 'Date of Birth'),
                readOnly: true,
                onTap: _selectDate,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Date of birth required';
                  }
                  try {
                    final date = DateTime.parse(value);
                    if (date.isAfter(DateTime.now())) {
                      return 'Invalid/future date';
                    }
                  } catch (e) {
                    return 'Invalid date format';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged:
                    _step == 'verify_code'
                        ? null
                        : (value) => setState(() => _gender = value),
                validator: (value) => value == null ? 'Gender required' : null,
              ),
              DropdownButtonFormField<String>(
                value: _state,
                decoration: const InputDecoration(labelText: 'State'),
                items:
                    _states
                        .map(
                          (state) => DropdownMenuItem(
                            value: state,
                            child: Text(state),
                          ),
                        )
                        .toList(),
                onChanged:
                    _step == 'verify_code'
                        ? null
                        : (value) => setState(() => _state = value),
                validator: (value) => value == null ? 'State required' : null,
              ),
              TextFormField(
                controller: _countryController,
                decoration: const InputDecoration(labelText: 'Country'),
                readOnly: true,
                validator:
                    (value) =>
                        value != null && value.length > 100
                            ? 'Country too long'
                            : null,
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 3,
                readOnly: _step == 'verify_code',
                validator:
                    (value) =>
                        value != null && value.length > 1000
                            ? 'Address too long'
                            : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _step == 'verify_code' ? null : _pickIdCard,
                child: const Text('Upload National ID Card'),
              ),
              if (_idCardFileName != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('Selected: $_idCardFileName'),
                ),
              const SizedBox(height: 20),
              if (_step == 'verify_code') ...[
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Verification Code',
                  ),
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Code required'
                              : null,
                ),
                const SizedBox(height: 20),
                if (_isWebcamInitialized) ...[
                  SizedBox(
                    height: 300,
                    child: HtmlElementView(
                      viewType: 'webcamVideoElement-$hashCode',
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  const Center(child: CircularProgressIndicator()),
                ],
                ElevatedButton(
                  onPressed: _takePicture,
                  child: const Text('Capture Face'),
                ),
                if (_imageBytes != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Image.memory(_imageBytes!, height: 200),
                  ),
              ],
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: _register,
                    child: Text(
                      _step == 'request_code' ? 'Request Code' : 'Register',
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  html.VideoElement? _webcamVideoElement;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _isWebcamInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeWebcam();
  }

  void _initializeWebcam() async {
    try {
      _webcamVideoElement = html.VideoElement();
      final stream = await html.window.navigator.getUserMedia(video: true);
      _webcamVideoElement!.srcObject = stream;
      await _webcamVideoElement!.play();
      setState(() {
        _isWebcamInitialized = true;
      });
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        'webcamVideoElement-$hashCode',
        (int viewId) => _webcamVideoElement!,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error accessing webcam: $e')));
    }
  }

  @override
  void dispose() {
    if (_webcamVideoElement != null) {
      final tracks = _webcamVideoElement!.srcObject?.getTracks();
      tracks?.forEach((track) => track.stop());
      _webcamVideoElement!.srcObject = null;
      _webcamVideoElement = null;
    }
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      if (!_isWebcamInitialized || _webcamVideoElement == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Webcam not initialized')));
        return;
      }
      final canvas = html.CanvasElement(
        width: _webcamVideoElement!.videoWidth,
        height: _webcamVideoElement!.videoHeight,
      );
      canvas.context2D.drawImage(_webcamVideoElement!, 0, 0);
      final dataUrl = canvas.toDataUrl('image/jpeg', 0.8);
      final bytes = base64Decode(dataUrl.split(',').last);
      if (bytes.length > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Facial image must be under 5MB')),
        );
        return;
      }
      setState(() {
        _imageBytes = bytes;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the errors in the form')),
      );
      return;
    }
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture a facial image')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final url = Uri.parse('http://127.0.0.1:5000/login');
    try {
      final base64Image = base64Encode(_imageBytes!);
      // Prepend the data URI prefix to match backend expectation
      final prefixedBase64Image = 'data:image/jpeg;base64,$base64Image';
      final body = jsonEncode({
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'image': prefixedBase64Image,
      });
      print('Login request body: $body'); // Debug log
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      );

      if (!mounted) return;

      if (response.body.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server returned an empty response')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final data = jsonDecode(response.body);

      if (data is Map<String, dynamic>) {
        final success = data['success'] as bool?;
        final message = data['message'] as String?;
        final token = data['token'] as String?;

        if (success == true && message != null) {
          final prefs = await SharedPreferences.getInstance();
          if (token != null) {
            await prefs.setString('jwt_token', token);
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          Navigator.pushReplacementNamed(context, '/vote');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message ?? 'Login failed: Unknown error')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid server response format')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator:
                    (value) =>
                        value == null ||
                                !RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(value)
                            ? 'Invalid email format'
                            : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Password is required'
                            : null,
              ),
              const SizedBox(height: 20),
              if (_isWebcamInitialized) ...[
                SizedBox(
                  height: 300,
                  child: HtmlElementView(
                    viewType: 'webcamVideoElement-$hashCode',
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                const Center(child: CircularProgressIndicator()),
              ],
              ElevatedButton(
                onPressed: _takePicture,
                child: const Text('Capture Face'),
              ),
              if (_imageBytes != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Image.memory(_imageBytes!, height: 200),
                ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: _login,
                    child: const Text('Login'),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class VoteScreen extends StatefulWidget {
  const VoteScreen({super.key});

  @override
  _VoteScreenState createState() => _VoteScreenState();
}

class _VoteScreenState extends State<VoteScreen> {
  List<Map<String, dynamic>> _candidates = [];
  String? _selectedCandidateId;
  String? _errorMessage;
  String _electionName = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCandidates();
  }

  Future<void> _fetchCandidates() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      setState(() {
        _errorMessage = 'Please log in to vote.';
        _isLoading = false;
      });
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final url = Uri.parse('http://127.0.0.1:5000/vote');
    try {
      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (data['success']) {
        setState(() {
          _electionName = data['election']['name'];
          _candidates = List<Map<String, dynamic>>.from(data['candidates']);
          _errorMessage = null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = data['message'];
          _isLoading = false;
        });
        if (_errorMessage?.contains('already cast your vote') ?? false) {
          Navigator.pushReplacementNamed(context, '/results');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching candidates: $e';
        _isLoading = false;
      });
      print('Fetch candidates error: $e');
    }
  }

  Future<void> _castVote() async {
    if (_selectedCandidateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a candidate')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      setState(() => _isLoading = false);
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final url = Uri.parse('http://127.0.0.1:5000/vote');
    try {
      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'candidate': _selectedCandidateId}),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Unknown error')),
      );

      if (data['success']) {
        setState(() => _isLoading = false);
        Navigator.pushReplacementNamed(context, '/results');
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Cast vote error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error casting vote: $e')));
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      setState(() => _isLoading = false);
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final url = Uri.parse('http://127.0.0.1:5000/logout');
    try {
      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Unknown error')),
      );

      if (data['success']) {
        await prefs.remove('jwt_token');
        setState(() => _isLoading = false);
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Logout error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cast Your Vote'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _logout,
              icon: const FaIcon(FontAwesomeIcons.signOutAlt, size: 16),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE3F2FD),
                foregroundColor: const Color(0xFF1976D2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _candidates.isEmpty
              ? const Center(child: Text('No candidates available'))
              : Container(
                padding: const EdgeInsets.all(32),
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.only(bottom: 24),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFFE3F2FD),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              FaIcon(
                                FontAwesomeIcons.voteYea,
                                color: Color(0xFF1976D2),
                                size: 28,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Cast Your Vote',
                                style: TextStyle(
                                  color: Color(0xFF1976D2),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Active Election: $_electionName',
                            style: const TextStyle(
                              color: Color(0xFF607D8B),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _candidates.length,
                        itemBuilder: (context, index) {
                          final candidate = _candidates[index];
                          final partyName = candidate['party'] ?? 'Independent';
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCandidateId =
                                    candidate['id'].toString();
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      _selectedCandidateId ==
                                              candidate['id'].toString()
                                          ? const Color(0xFF1976D2)
                                          : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const FaIcon(
                                              FontAwesomeIcons.userTie,
                                              color: Color(0xFF2D3436),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              candidate['name'],
                                              style: const TextStyle(
                                                color: Color(0xFF2D3436),
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                partyName == 'Independent'
                                                    ? const Color(0xFFFFF3E0)
                                                    : const Color(0xFFE3F2FD),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              FaIcon(
                                                partyName == 'Independent'
                                                    ? FontAwesomeIcons.star
                                                    : FontAwesomeIcons.flag,
                                                color:
                                                    partyName == 'Independent'
                                                        ? const Color(
                                                          0xFFEF6C00,
                                                        )
                                                        : const Color(
                                                          0xFF1976D2,
                                                        ),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                partyName,
                                                style: TextStyle(
                                                  color:
                                                      partyName == 'Independent'
                                                          ? const Color(
                                                            0xFFEF6C00,
                                                          )
                                                          : const Color(
                                                            0xFF1976D2,
                                                          ),
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF90CAF9),
                                        width: 2,
                                      ),
                                      color:
                                          _selectedCandidateId ==
                                                  candidate['id'].toString()
                                              ? const Color(0xFF1976D2)
                                              : Colors.transparent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.only(top: 32),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFE3F2FD), width: 2),
                        ),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _castVote,
                        icon: const FaIcon(
                          FontAwesomeIcons.checkCircle,
                          size: 20,
                        ),
                        label: const Text(
                          'Confirm Vote',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  _ResultsScreenState createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  Map<String, Map<String, dynamic>> _results = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      setState(() => _isLoading = false);
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final url = Uri.parse('http://127.0.0.1:5000/results');
    try {
      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (data['success']) {
        setState(() {
          _results = Map<String, Map<String, dynamic>>.from(data['results']);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Unknown error')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Fetch results error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching results: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            FaIcon(FontAwesomeIcons.pollH, size: 24),
            SizedBox(width: 8),
            Text('Election Results'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
              ? const Center(child: Text('No results available'))
              : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 32,
                ),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.only(bottom: 24),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFFE3EFFD),
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            FaIcon(
                              FontAwesomeIcons.pollH,
                              color: Color(0xFF2C3E50),
                              size: 32,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Election Results',
                              style: TextStyle(
                                color: Color(0xFF2C3E50),
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      ..._results.entries.map((electionEntry) {
                        final election = electionEntry.key;
                        final parties = electionEntry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 40),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.only(bottom: 16),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Color(0xFFF0F4F9),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  election,
                                  style: const TextStyle(
                                    color: Color(0xFF3498DB),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ...parties.entries.map((partyEntry) {
                                final party = partyEntry.key;
                                final data = partyEntry.value;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 32),
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFD),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            party,
                                            style: const TextStyle(
                                              color: Color(0xFF2980B9),
                                              fontSize: 20,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF3498DB),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '${data["party_votes"]} Total Votes',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Table(
                                        border: TableBorder.all(
                                          color: const Color(0xFFF0F4F9),
                                          width: 1,
                                        ),
                                        columnWidths: const {
                                          0: FlexColumnWidth(3),
                                          1: FlexColumnWidth(1),
                                        },
                                        children: [
                                          const TableRow(
                                            decoration: BoxDecoration(
                                              color: Color(0xFF3498DB),
                                            ),
                                            children: [
                                              Padding(
                                                padding: EdgeInsets.all(16),
                                                child: Text(
                                                  'Candidate',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.all(16),
                                                child: Text(
                                                  'Votes',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          ...data['candidates'].asMap().entries.map<
                                            TableRow
                                          >((candidateEntry) {
                                            final candidate =
                                                candidateEntry.value;
                                            return TableRow(
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                              ),
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  child: Text(
                                                    candidate['candidate_name'],
                                                    style: const TextStyle(
                                                      color: Color(0xFF2C3E50),
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  child: Text(
                                                    '${candidate['votes']}',
                                                    style: const TextStyle(
                                                      color: Color(0xFF2C3E50),
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                      Container(
                        padding: const EdgeInsets.only(top: 32),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFE3EFFD), width: 2),
                          ),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/');
                          },
                          icon: const FaIcon(
                            FontAwesomeIcons.arrowLeft,
                            size: 16,
                          ),
                          label: const Text(
                            'Return to Home',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3498DB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
