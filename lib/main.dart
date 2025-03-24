import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'screens/user_form_screen.dart';
import 'screens/login_screen.dart';
import 'screens/product_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fullstack Game',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[800],
          elevation: 0,
        ),
        cardTheme: CardTheme(elevation: 2, color: Colors.grey[50]),
      ),
      home: const UserListScreen(),
    );
  }
}

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  List<dynamic> users = [];
  bool isLoading = true;
  String? errorMessage;
  String? token;
  String? userRole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthentication();
    });
  }

  Future<void> _checkAuthentication() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    if (token == null) {
      await login();
    } else {
      await fetchUsers();
    }
  }

  Future<void> login() async {
    if (!mounted) return;
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );

      if (result != null && result is Map<String, dynamic>) {
        setState(() {
          token = result['token'];
          userRole = result['role'];
          errorMessage = null;
        });
        await fetchUsers();
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Please log in to continue';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Login error: ${e.toString()}';
      });
    }
  }

  Future<void> fetchUsers() async {
    if (!mounted) return;

    try {
      final Map<String, String> headers =
          token != null ? {'Authorization': 'Bearer $token'} : {};
      final response = await http
          .get(Uri.parse('http://10.0.2.2:5000/usuarios'), headers: headers)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'Connection timed out. Please check if the server is running.',
              );
            },
          );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          users = json.decode(response.body);
          isLoading = false;
          errorMessage = null;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          token = null;
          userRole = null;
        });
        await login();
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> deleteUser(String userId) async {
    if (token == null) {
      await login();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to delete users')),
        );
        return;
      }
    }

    if (userRole != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only administrators can delete users')),
      );
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('http://10.0.2.2:5000/usuarios/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        fetchUsers();
      } else if (response.statusCode == 401) {
        await login();
        deleteUser(userId);
      } else {
        throw Exception('Failed to delete user');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User List', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.shopping_cart, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        ProductListScreen(token: token, userRole: userRole),
              ),
            );
          },
        ),
        actions: [
          if (userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserFormScreen(token: token),
                  ),
                );
                if (result == true) {
                  fetchUsers();
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              setState(() {
                token = null;
                userRole = null;
              });
              login();
            },
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                ),
              )
              : errorMessage != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: fetchUsers,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text(
                        user['nombre'] ?? 'No name',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        user['correo'] ?? 'No email',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              user['rol'] ?? 'No role',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ),
                          if (userRole == 'admin') ...[
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => UserFormScreen(
                                          user: user,
                                          token: token,
                                        ),
                                  ),
                                );
                                if (result == true) {
                                  fetchUsers();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => deleteUser(user['_id']),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
