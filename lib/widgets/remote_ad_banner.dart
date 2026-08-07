import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:url_launcher/url_launcher.dart';

class RemoteAdBanner extends StatelessWidget {
  final bool shouldShow;

  const RemoteAdBanner({super.key, required this.shouldShow});

  Future<void> _handleTap(String targetUrl, String linkType) async {
    try {
      if (linkType == "mailto") {
        final email = targetUrl.replaceAll('mailto:', '').trim();
        final uri = Uri.parse('mailto:$email');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          debugPrint('Cannot launch email: $email');
        }
      } else {
        // web or fallback
        final uri = Uri.parse(targetUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Widget _buildFallback() {
    return Container(
      height: 65,
      color: const Color(0xFFF5F5F5), // Light gray background
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign, color: Colors.blueGrey[600], size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '本廣告欄位招租中 · 聯繫請洽 sampeng0206@gmail.com · 02-26971176',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF333333),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    final remoteConfig = FirebaseRemoteConfig.instance;
    
    // Retrieve values from Remote Config
    final bool isEnabled = remoteConfig.getBool('ad_banner_enabled');
    if (!isEnabled) {
      return const SizedBox.shrink();
    }

    final String imageUrl = remoteConfig.getString('ad_banner_image_url');
    final String targetUrl = remoteConfig.getString('ad_banner_target_url');
    final String linkType = remoteConfig.getString('ad_banner_link_type');

    return GestureDetector(
      onTap: () => _handleTap(targetUrl, linkType),
      child: Container(
        height: 65,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F5F5),
          border: Border(
            top: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
            bottom: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
          ),
        ),
        child: imageUrl.trim().isNotEmpty
            ? Image.network(
                imageUrl,
                height: 65,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 65,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallback();
                },
              )
            : _buildFallback(),
      ),
    );
  }
}