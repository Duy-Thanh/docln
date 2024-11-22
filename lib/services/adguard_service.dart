import 'package:http/http.dart' as http;

class AdBlockService {
  static const String ADGUARD_RULES_URL = 'https://filters.adtidy.org/extension/ublock/filters/2.txt';

  static Future<String> getAdBlockScript() async {
    try {
      // In the future, you can fetch rules from AdGuard or other sources
      // For now, return the fallback script
      return _getBasicAdBlockScript();
    } catch (e) {
      print('Error getting ad block script: $e');
      return _getBasicAdBlockScript();
    }
  }

  static String getFallbackScript() {
    return _getBasicAdBlockScript();
  }
  
  static Future<String> generateAdBlockScript() async {
    try {
      final response = await http.get(Uri.parse(ADGUARD_RULES_URL));
      if (response.statusCode == 200) {
        final rules = _parseAdGuardRules(response.body);
        return _generateJavaScript(rules);
      }
      throw Exception('Failed to fetch AdGuard rules');
    } catch (e) {
      print('Error fetching AdGuard rules: $e');
      // Return basic adblock script as fallback
      return _getBasicAdBlockScript();
    }
  }

  static List<String> _parseAdGuardRules(String rawRules) {
    final List<String> validRules = [];
    
    for (var line in rawRules.split('\n')) {
      line = line.trim();
      
      // Skip comments and empty lines
      if (line.isEmpty || line.startsWith('!') || line.startsWith('[')) {
        continue;
      }

      // Handle element hiding rules
      if (line.contains('##')) {
        final parts = line.split('##');
        if (parts.length == 2) {
          validRules.add(parts[1]);
        }
        continue;
      }

      // Handle domain-specific rules
      if (line.contains('#@#') || line.contains('#?#')) {
        continue;
      }

      // Add valid CSS selectors
      if (line.startsWith('.') || line.startsWith('#') || line.contains('*')) {
        validRules.add(line);
      }
    }

    return validRules;
  }

  static String _generateJavaScript(List<String> rules) {
    return '''
      function blockAds() {
        const selectors = ${rules.map((r) => "'$r'").toList()};
        
        // Remove elements matching AdGuard rules
        selectors.forEach(selector => {
          try {
            const elements = document.querySelectorAll(selector);
            elements.forEach(element => {
              element.style.display = 'none';
              // Optional: completely remove element
              element.remove();
            });
          } catch (e) {
            console.log('Error applying selector:', selector, e);
          }
        });

        // Additional custom rules
        ${_getBasicAdBlockScript()}
      }

      // Run immediately and observe DOM changes
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', blockAds);
      } else {
        blockAds();
      }

      const observer = new MutationObserver(() => {
        blockAds();
      });

      observer.observe(document.body || document.documentElement, {
        childList: true,
        subtree: true
      });
    ''';
  }

  static String _getBasicAdBlockScript() {
    return '''
      if (typeof blockAds === 'undefined') {
        function blockAds() {
          const commonAdSelectors = [
            // Common ad classes and IDs
            '.ads', '#ads', '.advertisement', '.advert',
            '[class*="ads-"]', '[id*="ads-"]',
            '[class*="advertisement"]', '[id*="advertisement"]',
            '[class*="advert"]', '[id*="advert"]',
            
            // Ad networks
            'ins.adsbygoogle', '.adsbygoogle',
            'div[data-ad]', 'div[class*="ad-"]',
            'iframe[src*="doubleclick.net"]',
            'iframe[src*="googleadservices"]',
            'iframe[src*="ad."]',
            
            // Banners and popups
            '.banner-ads', '#banner-ads',
            '.google-ads', '#google-ads',
            'div[class*="banner"]', 'div[id*="banner"]',
            'div[class*="popup"]', 'div[id*="popup"]',
            
            // Social widgets and tracking
            '.social-share', '.share-buttons',
            '[class*="tracking"]', '[id*="tracking"]',
            
            // Additional specific selectors for Hako
            '.quangcao', '#quangcao',
            '.ads-container', '.ads-wrapper',
            '[class*="sponsor"]', '[id*="sponsor"]'
          ];

          // Remove matching elements
          commonAdSelectors.forEach(selector => {
            document.querySelectorAll(selector).forEach(element => {
              element.remove();
            });
          });

          // Remove inline scripts
          const scripts = document.getElementsByTagName('script');
          const adKeywords = /(adsbygoogle|googleads|pagead2|advertisement|analytics|tracking|gtag)/i;
          for (let script of scripts) {
            if (script.innerHTML.match(adKeywords)) {
              script.remove();
            }
          }

          // Clean iframes
          document.querySelectorAll('iframe').forEach(iframe => {
            if (iframe.src.match(/(ads|analytics|tracking)/i)) {
              iframe.remove();
            }
          });
        }

        // Set up observer for dynamic content
        const adBlockObserver = new MutationObserver(() => {
          blockAds();
        });

        // Run immediately and observe DOM changes
        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', () => {
            blockAds();
            adBlockObserver.observe(document.body || document.documentElement, {
              childList: true,
              subtree: true
            });
          });
        } else {
          blockAds();
          adBlockObserver.observe(document.body || document.documentElement, {
            childList: true,
            subtree: true
          });
        }
      } else {
        // If already defined, just run it again
        blockAds();
      }
    ''';
  }
}