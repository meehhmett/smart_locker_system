import 'package:flutter/material.dart';

class HoverScale extends StatefulWidget {
  final Widget child;
  final double scale;
  final Duration duration;

  const HoverScale({
    super.key,
    required this.child,
    this.scale = 1.03,
    this.duration = const Duration(milliseconds: 150),
  });

  @override
  State<HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<HoverScale> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: AnimatedScale(
        scale: hovering ? widget.scale : 1,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

Widget iconCircle(IconData icon) => Container(
  width: 44,
  height: 44,
  decoration: BoxDecoration(
    color: const Color(0xff1b1f2b),
    shape: BoxShape.circle,
    border: Border.all(color: const Color(0xff2a3040)),
  ),
  child: Icon(icon, color: Colors.white),
);

Widget cardContainer({required Widget child}) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: const Color(0xff141824),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xff232738)),
  ),
  child: child,
);

Widget titleRow(IconData icon, String title) => Row(
  children: [
    Icon(icon, color: const Color(0xff6759ff)),
    const SizedBox(width: 10),
    Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
    ),
  ],
);

BoxDecoration innerDecoration() => BoxDecoration(
  color: const Color(0xff181c28),
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: const Color(0xff272c3d)),
);

Widget requestCard({required Widget child}) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: const Color(0xff141824),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xff232738)),
  ),
  child: child,
);

Widget sectionTitle(String text) => Text(
  text,
  style: const TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w800,
    fontSize: 20,
  ),
);
Widget sectionSub(String text) =>
    Text(text, style: const TextStyle(color: Colors.white38, fontSize: 14));

Widget pricingOption({
  required bool selected,
  required String title,
  required String subtitle,
  required String price,
  String? badge,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xff181c28),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: selected ? const Color(0xff6759ff) : const Color(0xff2a3040),
        width: selected ? 1.5 : 1,
      ),
    ),
    child: Row(
      children: [
        Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? const Color(0xff6759ff) : Colors.white30,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: Colors.white38)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              price,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xff6759ff),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

Widget durationButton(IconData icon, VoidCallback onTap, {required bool left}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 58,
      decoration: BoxDecoration(
        color: const Color(0xff242936),
        borderRadius: BorderRadius.horizontal(
          left: left ? const Radius.circular(14) : Radius.zero,
          right: left ? Radius.zero : const Radius.circular(14),
        ),
      ),
      child: Icon(icon, color: Colors.white),
    ),
  );
}

Widget darkInput({
  required TextEditingController controller,
  required String hint,
  required IconData icon,
  bool obscure = false,
}) {
  return TextField(
    controller: controller,
    obscureText: obscure,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      prefixIcon: Icon(icon, color: Colors.white38),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30),
      filled: true,
      fillColor: const Color(0xff181c28),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

Widget backButton(BuildContext context) => GestureDetector(
  onTap: () => Navigator.pop(context),
  child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
);

ButtonStyle purpleButtonStyle() => ElevatedButton.styleFrom(
  backgroundColor: const Color(0xff6759ff),
  disabledBackgroundColor: const Color(0xff262936),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);

ButtonStyle outlinePurpleButtonStyle() => OutlinedButton.styleFrom(
  side: const BorderSide(color: Color(0xff6759ff)),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);

class InfoRow extends StatelessWidget {
  final String left;
  final String right;
  final bool green;
  final bool bold;
  const InfoRow({
    super.key,
    required this.left,
    required this.right,
    this.green = false,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(left, style: const TextStyle(color: Colors.white54)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              right,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: green ? const Color(0xff7ce78c) : Colors.white,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PriceRow extends StatelessWidget {
  final String left;
  final String right;
  final bool green;
  const PriceRow({
    super.key,
    required this.left,
    required this.right,
    this.green = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Text(left, style: const TextStyle(color: Colors.white54)),
          const Spacer(),
          Text(
            right,
            style: TextStyle(
              color: green ? const Color(0xff7ce78c) : Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
