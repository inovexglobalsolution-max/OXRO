import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/app/widgets/press_scale.dart';
import 'package:oxro/features/account/data/profile_store.dart';

/// Edit profile — name + phone (email is login identity, read-only).
/// Fully static: no entrance slide/fade, no avatar breathing —
/// fields never jump (error space is reserved).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _nameError;
  String? _phoneError;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = ProfileStore.instance.name ?? '';
    _phoneCtrl.text = ProfileStore.instance.phone ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _nameError = null;
      _phoneError = null;
      _saving = true;
      _saved = false;
    });
    final err = await ProfileStore.instance.updateProfile(
      name: _nameCtrl.text,
      phone: _phoneCtrl.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      setState(() {
        if (err.contains('name')) {
          _nameError = err;
        } else {
          _phoneError = err;
        }
      });
      return;
    }
    setState(() => _saved = true);
    showOxroSnack(context, 'Profile updated');
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  InputDecoration _dec({
    required String label,
    required String hint,
    String? error,
    Widget? prefix,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: OxroColors.muted),
      errorText: error,
      prefix: prefix,
      prefixIcon: prefixIcon,
      counterText: '',
      // Reserved line keeps field height constant so showing an
      // error never pushes the fields below (no jump).
      helperText: ' ',
      helperStyle: const TextStyle(fontSize: 12, height: 1),
      errorStyle: const TextStyle(fontSize: 12, height: 1),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OxroColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OxroColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: OxroColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OxroColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.rs(8), vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back,
                        color: OxroColors.charcoal),
                  ),
                  const Expanded(
                    child: Text('Edit Profile',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: OxroColors.charcoal)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: ProfileStore.instance,
                builder: (context, _) {
                  final prof = ProfileStore.instance;
                  final initial = prof.displayName.isEmpty
                      ? '?'
                      : prof.displayName[0].toUpperCase();
                  return ListView(
                    key: const ValueKey('edit_scroll'),
                    padding: EdgeInsets.fromLTRB(
                        context.padX, 6, context.padX, 20),
                    children: [
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: OxroColors.primary
                                    .withValues(alpha: 0.12),
                              ),
                            ),
                            Container(
                              padding:
                                  const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white,
                                    width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: OxroColors.primary
                                        .withValues(
                                            alpha: 0.30),
                                    blurRadius: 18,
                                    offset:
                                        const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Container(
                                width: 72,
                                height: 72,
                                alignment: Alignment.center,
                                decoration:
                                    const BoxDecoration(
                                  gradient:
                                      OxroColors.gradient,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(initial,
                                    style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight:
                                            FontWeight.w800,
                                        color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.rs(16)),
                      TextField(
                          key:
                              const ValueKey('edit_name'),
                          controller: _nameCtrl,
                          textCapitalization:
                              TextCapitalization.words,
                          textInputAction:
                              TextInputAction.next,
                          onChanged: (_) {
                            if (_nameError != null) {
                              setState(
                                  () => _nameError = null);
                            }
                          },
                          onSubmitted: (_) =>
                              FocusScope.of(context)
                                  .nextFocus(),
                          decoration: _dec(
                            label: 'Full name',
                            hint: 'e.g. Sachin V',
                            error: _nameError,
                            prefixIcon: const Icon(
                                Icons.person_outline,
                                color: OxroColors.muted),
                          ),
                        ),
                      SizedBox(height: context.rs(10)),
                      TextField(
                          key:
                              const ValueKey('edit_phone'),
                          controller: _phoneCtrl,
                          keyboardType:
                              TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter
                                .digitsOnly
                          ],
                          textInputAction:
                              TextInputAction.done,
                          onChanged: (_) {
                            if (_phoneError != null) {
                              setState(() =>
                                  _phoneError = null);
                            }
                          },
                          onSubmitted: (_) => _save(),
                          decoration: _dec(
                            label: 'Phone number',
                            hint: '10-digit mobile',
                            error: _phoneError,
                            prefix: const Padding(
                              padding: EdgeInsets.only(
                                  right: 8),
                              child: Text('+91',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight:
                                          FontWeight.w700,
                                      color: OxroColors
                                          .charcoal)),
                            ),
                            prefixIcon: const Icon(
                                Icons.call_outlined,
                                color: OxroColors.muted),
                          ),
                        ),
                      SizedBox(height: context.rs(10)),
                      TextField(
                          controller: TextEditingController(
                              text: prof.email ?? ''),
                          readOnly: true,
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Email (login)',
                            filled: true,
                            fillColor: Colors.white
                                .withValues(alpha: 0.6),
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14),
                            prefixIcon: const Icon(
                                Icons.mail_outline,
                                color: OxroColors.muted),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      12),
                              borderSide:
                                  const BorderSide(
                                      color:
                                          OxroColors.border),
                            ),
                            disabledBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      12),
                              borderSide:
                                  const BorderSide(
                                      color:
                                          OxroColors.border),
                            ),
                          ),
                        ),
                      SizedBox(height: context.rs(16)),
                      PressScale(
                          key:
                              const ValueKey('edit_save'),
                          onTap: _save,
                          child: AnimatedContainer(
                            duration: const Duration(
                                milliseconds: 250),
                            height: context.btnH,
                            constraints:
                                const BoxConstraints(
                                    minHeight: 48),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: _saved
                                  ? const LinearGradient(
                                      colors: [
                                          Colors.green,
                                          Color(
                                              0xFF16A34A)
                                        ])
                                  : OxroColors.gradient,
                              borderRadius:
                                  BorderRadius.circular(
                                      context.rs(12)),
                              boxShadow: [
                                BoxShadow(
                                  color: (_saved
                                          ? Colors.green
                                          : OxroColors
                                              .primary)
                                      .withValues(
                                          alpha: 0.35),
                                  blurRadius: 14,
                                  offset:
                                      const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                if (_saving)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  Icon(
                                      _saved
                                          ? Icons.check_circle
                                          : Icons.save_outlined,
                                      color: Colors.white,
                                      size: 20),
                                const SizedBox(width: 8),
                                Text(
                                    _saving
                                        ? 'Saving...'
                                        : _saved
                                            ? 'Saved!'
                                            : 'Save Changes',
                                    style: TextStyle(
                                        fontSize: context
                                            .font(16),
                                        fontWeight:
                                            FontWeight.w700,
                                        color:
                                            Colors.white)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
