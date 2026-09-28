import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tema ile uyumlu, şifre görünürlüğü destekleyen metin alanı.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.validator,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.prefixIcon,
    this.suffix,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.focusNode,
    this.helperText,
    this.errorText,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? Function(String?)? validator;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final String? helperText;
  final String? errorText;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      validator: widget.validator,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      maxLength: widget.maxLength,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      minLines: widget.minLines,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helperText,
        errorText: widget.errorText,
        counterText: widget.maxLength == null ? null : '',
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon, size: 20),
        suffixIcon: widget.obscure
            ? IconButton(
                icon: Icon(_obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : widget.suffix,
      ),
    );
  }
}
