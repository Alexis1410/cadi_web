import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserAdminPage extends StatefulWidget {
  const UserAdminPage({super.key});

  @override
  State<UserAdminPage> createState() => _UserAdminPageState();
}

class _UserAdminPageState extends State<UserAdminPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  /// Rol y área por defecto
  String _role = 'empleado';
  String _area = 'Cocina';
  bool _active = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  String _mapCreateError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'El correo ya está registrado.';
      case 'invalid-email':
        return 'Correo inválido.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'operation-not-allowed':
        return 'El registro por correo está deshabilitado en Firebase.';
      default:
        return 'Error de autenticación: ${e.code}';
    }
  }

  /// Indica si este rol tiene permisos de autorización (aprobación de movimientos).
  bool _roleCanAuthorize(String role) {
    // admin y gerente pueden autorizar; supervisor y empleado no.
    switch (role) {
      case 'admin':
      case 'gerente':
        return true;
      default:
        return false;
    }
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    final pass = _passCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();

    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      final email = _emailCtrl.text.trim();

      // 1) Crear usuario en Firebase Auth
      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final uid = cred.user!.uid;

      // 2) Guardar info extra en Firestore
      await firestore.collection('users').doc(uid).set({
        'name': _nameCtrl.text.trim(),
        'email': email,
        'role': _role,
        'area': _area,
        'active': _active,
        'canAuthorize': _roleCanAuthorize(_role),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3) Limpiar formulario
      _formKey.currentState!.reset();
      _nameCtrl.clear();
      _emailCtrl.clear();
      _passCtrl.clear();
      _confirmPassCtrl.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        _role = 'empleado';
        _area = 'Cocina';
        _active = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario creado correctamente')),
        );
      }
    } on FirebaseAuthException catch (e) {
      final msg = _mapCreateError(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear usuario: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// Crea un usuario de prueba automáticamente (correo + contraseña fija)
  Future<void> _createDemoUser() async {
    setState(() => _saving = true);

    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      final email =
          'usuario${DateTime.now().millisecondsSinceEpoch}@cadi.com';
      const password = 'Cadi123456'; // misma que usarás en el login

      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await firestore.collection('users').doc(cred.user!.uid).set({
        'name': 'Usuario Demo',
        'email': email,
        'role': 'empleado',
        'area': 'Mermas',
        'active': true,
        'canAuthorize': _roleCanAuthorize('empleado'), // normalmente false
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Usuario demo creado:\n$email\nContraseña: $password',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      final msg = _mapCreateError(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear usuario demo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// Activar / desactivar usuario (dar de baja / alta)
  Future<void> _toggleActive(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final bool active = data['active'] ?? true;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(doc.id)
          .update({'active': !active});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!active
                ? 'Usuario reactivado'
                : 'Usuario dado de baja'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar estado: $e')),
        );
      }
    }
  }

  /// Ver descripción / detalle del usuario
  void _showUserDetail(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final bool active = data['active'] ?? true;
    final bool canAuthorize = data['canAuthorize'] ?? false;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detalle de usuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nombre: ${data['name'] ?? ''}'),
            Text('Correo: ${data['email'] ?? ''}'),
            const SizedBox(height: 8),
            Text('Rol: ${data['role'] ?? '—'}'),
            Text('Área: ${data['area'] ?? '—'}'),
            const SizedBox(height: 8),
            Text('Estado: ${active ? 'Activo' : 'Inactivo'}'),
            Text('Autoriza movimientos: ${canAuthorize ? 'Sí' : 'No'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersStream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios CADI (panel web)'),
      ),
      body: Column(
        children: [
          // FORMULARIO
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nombre completo',
                                prefixIcon: Icon(Icons.person),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Ingresa el nombre';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Correo',
                                prefixIcon: Icon(Icons.email),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Ingresa el correo';
                                }
                                if (!value.contains('@')) {
                                  return 'Correo no válido';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _passCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Ingresa una contraseña';
                                }
                                if (value.length < 6) {
                                  return 'Mínimo 6 caracteres';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _confirmPassCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Confirmar contraseña',
                                prefixIcon: Icon(Icons.lock_reset_outlined),
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Confirma la contraseña';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Rol',
                              ),
                              value: _role,
                              items: const [
                                DropdownMenuItem(
                                  value: 'admin',
                                  child: Text('Administrador'),
                                ),
                                DropdownMenuItem(
                                  value: 'gerente',
                                  child: Text('Gerente / Jefe de área'),
                                ),
                                DropdownMenuItem(
                                  value: 'supervisor',
                                  child: Text('Supervisor'),
                                ),
                                DropdownMenuItem(
                                  value: 'empleado',
                                  child: Text('Empleado'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _role = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Área',
                              ),
                              value: _area,
                              items: const [
                                DropdownMenuItem(
                                  value: 'Cocina',
                                  child: Text('Cocina'),
                                ),
                                DropdownMenuItem(
                                  value: 'Panadería',
                                  child: Text('Panadería'),
                                ),
                                DropdownMenuItem(
                                  value: 'Mermas',
                                  child: Text('Mermas'),
                                ),
                                DropdownMenuItem(
                                  value: 'Recibo',
                                  child: Text('Recibo'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _area = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Usuario activo'),
                        value: _active,
                        onChanged: (v) {
                          setState(() => _active = v);
                        },
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _saveUser,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            _saving ? 'Procesando...' : 'Guardar usuario',
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _createDemoUser,
                          icon: const Icon(Icons.auto_awesome),
                          label: Text(
                            _saving
                                ? 'Procesando...'
                                : 'Generar usuario demo',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const Divider(),

          // LISTA DE USUARIOS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: usersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar usuarios: ${snapshot.error}',
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No hay usuarios registrados.'),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Nombre')),
                      DataColumn(label: Text('Correo')),
                      DataColumn(label: Text('Rol')),
                      DataColumn(label: Text('Área')),
                      DataColumn(label: Text('Estado')),
                      DataColumn(label: Text('Autoriza')),
                      DataColumn(label: Text('Acciones')),
                    ],
                    rows: docs.map((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final canAuthorize = data['canAuthorize'] ?? false;
                      final active = data['active'] ?? true;

                      return DataRow(
                        cells: [
                          DataCell(Text(data['name'] ?? '')),
                          DataCell(Text(data['email'] ?? '')),
                          DataCell(Text(data['role'] ?? '')),
                          DataCell(Text(data['area'] ?? '')),
                          DataCell(
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        active ? Colors.green : Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(active ? 'Activo' : 'Inactivo'),
                              ],
                            ),
                          ),
                          DataCell(
                            Icon(
                              canAuthorize
                                  ? Icons.verified
                                  : Icons.block_outlined,
                              color:
                                  canAuthorize ? Colors.indigo : Colors.grey,
                              size: 20,
                            ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  tooltip: active
                                      ? 'Dar de baja'
                                      : 'Reactivar',
                                  icon: Icon(
                                    active
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 20,
                                  ),
                                  onPressed: () => _toggleActive(d),
                                ),
                                IconButton(
                                  tooltip: 'Ver detalle',
                                  icon: const Icon(
                                    Icons.info_outline,
                                    size: 20,
                                  ),
                                  onPressed: () => _showUserDetail(d),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}