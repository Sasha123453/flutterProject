import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

String? _token = "";
final String address = "https://dc555ac609307d.lhr.life";

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login() async {
    final response = await http.post(
      Uri.parse('$address/user/auth'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': _usernameController.text,
        'password': _passwordController.text,
      }),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final token = responseData['jwt'];

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      _token = token;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PhotoListPage()),
      );
    } else {
      print('Login failed');
    }
  }

  void _navigateToRegisterPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: Text('Login'),
            ),
            TextButton(
              onPressed: _navigateToRegisterPage,
              child: Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _register() async {
    final response = await http.post(
      Uri.parse('$address/user/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': _usernameController.text,
        'email': _emailController.text,
        'password': _passwordController.text,
      }),
    );

    if (response.statusCode == 200) {
      Navigator.pop(context);
    } else {
      print('Registration failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _register,
              child: Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}

class PhotoListPage extends StatefulWidget {
  @override
  _PhotoListPageState createState() => _PhotoListPageState();
}

class _PhotoListPageState extends State<PhotoListPage> {
  List<Map<String, dynamic>> _photos = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('token') ?? "";
    });
    _fetchPhotos();
  }

  Future<void> _fetchPhotos() async {
    final response = await http.get(
      Uri.parse('$address/photo'),
      headers: {
        'Authorization': 'Bearer $_token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> photoList = jsonDecode(response.body);
      setState(() {
        _photos = photoList.cast<Map<String, dynamic>>();
      });
    } else {
      print('Failed to load photos');
    }
  }

  Future<void> _uploadPhoto() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$address/photo/post'),
    );
    request.headers['Authorization'] = 'Bearer $_token';
    var filePath = pickedFile.path;
    var file = await http.MultipartFile.fromPath(
      'file',
      filePath,
      filename: path.basename(filePath),
    );
    request.files.add(file);

    var response = await request.send();

    if (response.statusCode == 200) {
      _fetchPhotos();
    } else {
      print('Failed to upload photo');
    }
  }

  Future<void> _likePhoto(int photoId) async {
    final response = await http.post(
      Uri.parse('$address/photo/like?photoId=$photoId'),
      headers: {
        'Authorization': 'Bearer $_token',
      },
    );

    if (response.statusCode == 200) {
      print('Photo liked successfully');
      _fetchPhotos();
    } else {
      print('Failed to like photo');
    }
  }

  Future<void> _commentOnPhoto(int photoId) async {
    final TextEditingController _commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Post a Comment'),
          content: TextField(
            controller: _commentController,
            decoration: InputDecoration(labelText: 'Comment'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                final response = await http.post(
                  Uri.parse('$address/photo/post/comment'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $_token',
                  },
                  body: jsonEncode({
                    'photo_id': photoId,
                    'text': _commentController.text,
                  }),
                );

                if (response.statusCode == 200) {
                  Navigator.of(context).pop();
                  print('Comment posted successfully');
                  _fetchPhotos();
                } else {
                  print('Failed to post comment');
                }
              },
              child: Text('Post'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showComments(int photoId) async {
    final response = await http.get(
      Uri.parse('$address/photo/comment/$photoId'),
      headers: {
        'Authorization': 'Bearer $_token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> comments = jsonDecode(response.body);
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Comments'),
            content: SingleChildScrollView(
              child: ListBody(
                children: comments.map((comment) {
                  return ListTile(
                    title: Text(comment['text']),
                    subtitle: Text('By: ${comment['username']}'),
                  );
                }).toList(),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Close'),
              ),
              TextButton(
                onPressed: () => _commentOnPhoto(photoId),
                child: Text('Add Comment'),
              ),
            ],
          );
        },
      );
    } else {
      print('Failed to load comments');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Photos'),
        actions: [
          IconButton(
            icon: Icon(Icons.add_a_photo),
            onPressed: _uploadPhoto,
          ),
        ],
      ),
      body: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
        ),
        itemCount: _photos.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _likePhoto(_photos[index]["ID"]),
            child: GridTile(
              child: Image.network(
                '$address/photo/path?path=${_photos[index]["image_url"]}',
                headers: {
                  'Authorization': 'Bearer $_token',
                },
                errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                  return Text('Can not load image');
                },
              ),
              footer: GridTileBar(
                backgroundColor: Colors.black54,
                title: Text('Photo ${_photos[index]["image_url"]}'),
                subtitle: Text('Likes: ${_photos[index]["likes"]}'),
                trailing: IconButton(
                  icon: Icon(Icons.comment),
                  onPressed: () => _showComments(_photos[index]["ID"]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
