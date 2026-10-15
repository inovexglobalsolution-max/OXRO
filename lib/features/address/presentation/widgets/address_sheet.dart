import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/location/data/geo_store.dart';

/// Bottom-sheet address form (add + edit).
/// Returns true when a valid address is saved, false/null on dismiss.
/// Invalid submit shows field errors + caller re-pops the message.
class AddressSheet extends StatefulWidget {
  const AddressSheet({super.key, this.existing});

  /// Prefill for edit; null for add.
  final Address? existing;

  /// Opens the sheet; true = saved valid address.
  static Future<bool> open(BuildContext context,
      {Address? existing}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddressSheet(existing: existing),
    );
    return ok ?? false;
  }

  @override
  State<AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<AddressSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _line = TextEditingController();
  final _city = TextEditingController();
  final _pin = TextEditingController();
  String _label = AddressStore.labels.first;

  String? _nameErr;
  String? _phoneErr;
  String? _lineErr;
  String? _cityErr;
  String? _pinErr;

  @override
  void initState() {
    super.initState();
    final a = widget.existing ??
        AddressStore.instance.address;
    if (widget.existing == null) {
      // Add mode: keep current default values empty for fresh entry,
      // except when only one address exists (prefill convenience).
      if (AddressStore.instance.items.length == 1 &&
          a != null) {
        _name.text = a.name;
        _phone.text = a.phone;
        _line.text = a.line;
        _city.text = a.city;
        _pin.text = a.pin;
        _label = a.label;
      } else {
        // Fresh entry: prefill detected city (GPS/IP, India-only).
        final detected = GeoStore.instance.city?.trim() ?? '';
        if (detected.isNotEmpty) _city.text = detected;
      }
    } else {
      _name.text = a!.name;
      _phone.text = a.phone;
      _line.text = a.line;
      _city.text = a.city;
      _pin.text = a.pin;
      _label = a.label;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _line.dispose();
    _city.dispose();
    _pin.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint, String? err, {Widget? prefix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: OxroColors.muted),
      prefixIcon: prefix,
      errorText: err,
      counterText: '',
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
        borderSide: const BorderSide(
            color: OxroColors.primary, width: 1.5),
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

  void _save() {
    setState(() {
      _nameErr = AddressStore.validateName(_name.text);
      _phoneErr = AddressStore.validatePhone(_phone.text);
      _lineErr = AddressStore.validateLine(_line.text);
      _cityErr = AddressStore.validateCity(_city.text);
      _pinErr = AddressStore.validatePin(_pin.text);
    });
    if (_nameErr != null ||
        _phoneErr != null ||
        _lineErr != null ||
        _cityErr != null ||
        _pinErr != null) {
      return;
    }
    FocusScope.of(context).unfocus();
    final data = Address(
      id: widget.existing?.id ?? '',
      label: _label,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      line: _line.text.trim(),
      city: _city.text.trim(),
      pin: _pin.text.trim(),
    );
    if (widget.existing == null) {
      AddressStore.instance.add(data);
    } else {
      AddressStore.instance
          .update(widget.existing!.id, data);
    }
    Navigator.of(context).pop(true);
  }

  Widget _labelRow() {
    return Row(
      children: [
        for (final l in AddressStore.labels)
          Expanded(
            child: GestureDetector(
              key: ValueKey('addr_label_$l'),
              onTap: () => setState(() => _label = l),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration:
                    const Duration(milliseconds: 200),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                    vertical: 9),
                margin: EdgeInsets.only(
                    right: l == AddressStore.labels.last
                        ? 0
                        : 8),
                decoration: BoxDecoration(
                  color: _label == l
                      ? OxroColors.primary
                      : Colors.white,
                  borderRadius:
                      BorderRadius.circular(10),
                  border: Border.all(
                    color: _label == l
                        ? OxroColors.primary
                        : OxroColors.border,
                  ),
                ),
                child: Text(l,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _label == l
                            ? Colors.white
                            : OxroColors.charcoal)),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                context.padX, 8, context.padX, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: OxroColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Delivery Address',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: OxroColors.charcoal)),
                const SizedBox(height: 4),
                const Text('We deliver across India',
                    style: TextStyle(
                        fontSize: 12,
                        color: OxroColors.muted)),
                const SizedBox(height: 12),
                _labelRow(),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('addr_name'),
                  controller: _name,
                  textCapitalization:
                      TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: _dec('Full name', _nameErr,
                      prefix: const Icon(
                          Icons.person_outline,
                          color: OxroColors.muted)),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('addr_phone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  textInputAction: TextInputAction.next,
                  decoration: _dec('10-digit mobile', _phoneErr,
                      prefix: const Icon(Icons.call_outlined,
                          color: OxroColors.muted)),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('addr_line'),
                  controller: _line,
                  textInputAction: TextInputAction.next,
                  maxLines: 2,
                  minLines: 1,
                  decoration: _dec(
                      'Flat / street / area', _lineErr,
                      prefix: const Icon(
                          Icons.home_outlined,
                          color: OxroColors.muted)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('addr_city'),
                        controller: _city,
                        textCapitalization:
                            TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: _dec('City', _cityErr),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('addr_pin'),
                        controller: _pin,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter
                              .digitsOnly
                        ],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _save(),
                        decoration:
                            _dec('Pincode', _pinErr),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  key: const ValueKey('addr_save'),
                  onTap: _save,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    height: context.btnH,
                    constraints: const BoxConstraints(
                        minHeight: 48),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: OxroColors.primary,
                      borderRadius: BorderRadius.circular(
                          context.rs(12)),
                    ),
                    child: Text('Save & Continue',
                        style: TextStyle(
                            fontSize: context.font(16),
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
