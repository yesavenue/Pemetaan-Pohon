import 'package:flutter/material.dart';
import '../../utils/branding.dart';
import '../public_navbar.dart';
import 'public_ui.dart';

class PublicFooter extends StatelessWidget {
  final PublicPage currentPage;
  const PublicFooter({super.key, required this.currentPage});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 40),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: PublicUi.border)),
    ),
    child: PublicContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final identity = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(appLogoAsset, width: 40, height: 40),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          appSystemName,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(appInstansiUnit),
                  const SizedBox(height: 8),
                  const SelectableText(appContactEmail),
                  if (appContactPhone.trim().isNotEmpty &&
                      appContactPhone != '(0231) 000000')
                    const SelectableText(appContactPhone),
                  const SizedBox(height: 8),
                  const Text(
                    appContactAddress,
                    style: TextStyle(color: PublicUi.muted, fontSize: 14),
                  ),
                ],
              );
              const links = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.park_rounded, color: PublicUi.green, size: 32),
                  SizedBox(height: 12),
                  Text(
                    'Satu kota. Ruang hijau bersama.',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Kenali sebaran pohon dan ikut merawat lingkungan di sekitar kita.',
                    style: TextStyle(color: PublicUi.muted),
                  ),
                ],
              );
              return box.maxWidth >= 850 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 18.2
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: 64),
                        Expanded(child: links),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [identity, const SizedBox(height: 24), links],
                    );
            },
          ),
          const SizedBox(height: 24),
          const Divider(color: PublicUi.border),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Mengenali pohon, merawat ruang hijau bersama.',
                style: TextStyle(fontSize: 14, color: PublicUi.muted),
              ),
              TextButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: appSystemName,
                ),
                child: const Text('Lihat lisensi'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}