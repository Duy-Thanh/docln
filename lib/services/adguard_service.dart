import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show compute;

class AdBlockService {
  // Multiple filter lists for better coverage
  static const List<String> FILTER_LISTS = [
    'https://filters.adtidy.org/extension/ublock/filters/2.txt', // AdGuard Base filter
    'https://filters.adtidy.org/extension/ublock/filters/11.txt', // Mobile Ads filter
    'https://easylist.to/easylist/easylist.txt', // EasyList standard
    'https://filters.adtidy.org/extension/ublock/filters/3.txt', // AdGuard Tracking Protection
    'https://filters.adtidy.org/extension/ublock/filters/14.txt', // Annoyances
    'https://filters.adtidy.org/extension/ublock/filters/224.txt', // Vietnamese filter
  ];

  static const String CACHE_KEY = 'adblock_rules_cache';
  static const Duration CACHE_DURATION = Duration(days: 3);

  static Future<String> getAdBlockScript() async {
    try {
      // Check for cached rules first
      final cachedScript = await _getCachedScript();
      if (cachedScript != null) {
        return cachedScript;
      }

      // Fetch and generate rules
      return await generateAdBlockScript();
    } catch (e) {
      print('Error getting ad block script: $e');
      return getFallbackScript();
    }
  }

  static Future<String?> _getCachedScript() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(CACHE_KEY);

      if (cacheData != null) {
        final cacheJson = json.decode(cacheData);
        final timestamp = DateTime.fromMillisecondsSinceEpoch(
          cacheJson['timestamp'],
        );
        final now = DateTime.now();

        // Check if cache is still valid
        if (now.difference(timestamp) < CACHE_DURATION) {
          return cacheJson['script'];
        }
      }
      return null;
    } catch (e) {
      print('Error accessing cache: $e');
      return null;
    }
  }

  static Future<void> _cacheScript(String script) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = json.encode({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'script': script,
      });

      await prefs.setString(CACHE_KEY, cacheData);
    } catch (e) {
      print('Error caching script: $e');
    }
  }

  static String getFallbackScript() {
    return _getBasicAdBlockScript();
  }

  static Future<String> generateAdBlockScript() async {
    try {
      final List<String> allRules = [];

      // Fetch rules from all filter lists with parallel processing
      final futures = FILTER_LISTS.map((url) => _fetchFilterList(url));
      final results = await Future.wait(futures);

      // Combine all rules
      for (var rules in results) {
        allRules.addAll(rules);
      }

      // Process rules in isolation for better performance
      final uniqueRules = await compute(_deduplicateRules, allRules);

      // Generate script with the rules
      final script = _generateJavaScript(uniqueRules);

      // Cache the script
      await _cacheScript(script);

      return script;
    } catch (e) {
      print('Error generating AdBlock script: $e');
      return _getBasicAdBlockScript();
    }
  }

  // Isolated function to fetch and parse rules from a filter list
  static Future<List<String>> _fetchFilterList(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Request timed out'),
          );

      if (response.statusCode == 200) {
        // Process rules in isolation for better performance
        return compute(_parseAdGuardRules, response.body);
      }
    } catch (e) {
      print('Error fetching filter from $url: $e');
    }
    return [];
  }

  // Isolated function to deduplicate rules
  static List<String> _deduplicateRules(List<String> rules) {
    return rules.toSet().toList();
  }

  // Isolated function to parse AdGuard rules
  static List<String> _parseAdGuardRules(String rawRules) {
    final List<String> validRules = [];
    final List<String> networkFilters = [];

    for (var line in rawRules.split('\n')) {
      line = line.trim();

      // Skip comments, empty lines, and other non-rules
      if (line.isEmpty || line.startsWith('!') || line.startsWith('[')) {
        continue;
      }

      // Handle element hiding rules
      if (line.contains('##')) {
        final parts = line.split('##');
        if (parts.length == 2) {
          // Parse domain-specific element hiding rules
          final selector = parts[1].trim();
          if (_isValidCssSelector(selector)) {
            validRules.add(selector);
          }
        }
        continue;
      }

      // Skip exception rules and complex rules we can't handle
      if (line.contains('#@#') || line.contains('#?#') || line.contains('@@')) {
        continue;
      }

      // Collect network filters for request blocking
      if (_isNetworkFilter(line)) {
        networkFilters.add(_sanitizeFilter(line));
        continue;
      }

      // Handle extended CSS selectors if they look valid
      if (line.startsWith('.') ||
          line.startsWith('#') ||
          line.contains('[') && line.contains(']') ||
          line.contains('*') && !line.contains('*:')) {
        if (_isValidCssSelector(line)) {
          validRules.add(line);
        }
      }
    }

    // Add network filters as special CSS rules that can be handled in JavaScript
    if (networkFilters.isNotEmpty) {
      validRules.add('/* NETWORK_FILTERS: ${json.encode(networkFilters)} */');
    }

    return validRules;
  }

  static bool _isNetworkFilter(String filter) {
    // Identify standalone URL filters or domain blocks
    if (filter.startsWith('||') ||
        filter.startsWith('|http') ||
        filter.contains('^') ||
        filter.contains('*\$') ||
        filter.contains('\$domain=')) {
      return true;
    }
    return false;
  }

  static String _sanitizeFilter(String filter) {
    // Clean up filter for JavaScript processing
    return filter.replaceAll('\'', '\\\'').replaceAll('\\', '\\\\');
  }

  static bool _isValidCssSelector(String selector) {
    try {
      // Basic validation - reject complex selectors that will throw errors
      if (selector.contains(':has(') ||
          selector.contains(':not(') && selector.split(':not(').length > 2 ||
          selector.contains(',,') ||
          selector.contains('  ') ||
          selector.contains('[href*=')) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  static String _generateJavaScript(List<String> rules) {
    // Extract network filters from special comments
    final networkFilters = _extractNetworkFilters(rules);

    // Limit the number of rules to prevent massive scripts
    List<String> cssRules =
        rules.where((rule) => !rule.startsWith('/* NETWORK_FILTERS')).toList();
    final limitedRules =
        cssRules.length > 5000 ? cssRules.sublist(0, 5000) : cssRules;

    return '''
      (function() {
        // Store a reference to blockAds if already defined
        const existingBlockAds = window.blockAds;
        
        // Network request blocking setup
        ${_generateNetworkBlockingScript(networkFilters)}
        
        function blockAdsWithRules() {
          const selectors = ${limitedRules.map((r) => r.contains("'") ? "\"$r\"" : "'$r'").toList()};
        
          // Apply AdGuard rules in batches to improve performance
          function applySelectors(selectors, startIndex, batchSize) {
            const endIndex = Math.min(startIndex + batchSize, selectors.length);
            const batch = selectors.slice(startIndex, endIndex);
            
            if (batch.length === 0) return;
            
            // Join selectors for more efficient DOM operations
          try {
              const elements = document.querySelectorAll(batch.join(', '));
              elements.forEach(function(element) {
              element.style.display = 'none';
              element.remove();
            });
          } catch (e) {
              // If batch fails, try individual selectors
              batch.forEach(function(selector) {
                try {
                  document.querySelectorAll(selector).forEach(function(el) { el.remove(); });
                } catch (err) {
                  // Silently fail for invalid selectors
                }
              });
            }
            
            // Process next batch
            if (endIndex < selectors.length) {
              setTimeout(function() {
                applySelectors(selectors, endIndex, batchSize);
              }, 0);
            }
          }
          
          // Smart filtering - prioritize visible elements
          function applySmartFiltering() {
            // First handle high-priority items that are likely ads
            const highPrioritySelectors = [
              // iframes are high priority as they often contain ads
              'iframe[src*="ad"]', 'iframe[src*="banner"]', 'iframe[src*="sponsor"]', 'iframe[id*="google_ads"]',
              // Common ad containers
              'div[id*="div-gpt-ad"]', '[id*="adunit"]', '[class*="ad-unit"]',
              // Sticky elements and overlays
              'div[style*="position:fixed"][style*="z-index"]', 'div[class*="popup"]', 'div[class*="modal"]'
            ];
            
            try {
              document.querySelectorAll(highPrioritySelectors.join(', ')).forEach(function(el) { el.remove(); });
            } catch (e) {
              // Fallback to individual processing
              highPrioritySelectors.forEach(function(sel) {
                try { document.querySelectorAll(sel).forEach(function(el) { el.remove(); }); } catch (e) {}
              });
            }
            
            // Now handle visible elements first, then proceed with batch processing
            const viewportHeight = window.innerHeight;
            const viewportSelectors = selectors.slice(0, 100); // Take first 100 selectors for viewport check
            
            viewportSelectors.forEach(function(selector) {
              try {
                document.querySelectorAll(selector).forEach(function(el) {
                  const rect = el.getBoundingClientRect();
                  // If element is in viewport or close to it
                  if (rect.bottom >= -100 && rect.top <= viewportHeight + 100) {
                    el.remove();
                  }
                });
              } catch (e) {
                // Silently fail for invalid selectors
              }
            });
          }
          
          // First run smart filtering for visible elements
          applySmartFiltering();
          
          // Start processing all selectors in batches
          applySelectors(selectors, 0, 100);
          
          // Apply basic ad blocking for common patterns
        ${_getBasicAdBlockScript()}
      }

        // Define global blockAds function
        window.blockAds = function() {
          blockAdsWithRules();
          // Call the original if it existed
          if (existingBlockAds && existingBlockAds !== window.blockAds) {
            existingBlockAds();
          }
        };
        
        // Run immediately
      if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', window.blockAds);
      } else {
          window.blockAds();
      }

        // Set up observer for dynamic content with throttling
        let timeout = null;
        const observer = new MutationObserver(function() {
          if (timeout) return;
          timeout = setTimeout(function() {
            window.blockAds();
            timeout = null;
          }, 500);
        });
        
        // Observe document
        if (document.body || document.documentElement) {
      observer.observe(document.body || document.documentElement, {
        childList: true,
        subtree: true
      });
        } else {
          // If body not available yet, wait and try again
          window.addEventListener('DOMContentLoaded', function() {
            observer.observe(document.body, {
              childList: true,
              subtree: true
            });
          });
        }
        
        // Run blocking code at regular intervals to catch dynamically loaded ads
        setInterval(window.blockAds, 3000);
      })();
    ''';
  }

  static List<String> _extractNetworkFilters(List<String> rules) {
    for (var rule in rules) {
      if (rule.startsWith('/* NETWORK_FILTERS:')) {
        try {
          final jsonStr = rule.substring(19, rule.length - 3);
          return List<String>.from(json.decode(jsonStr));
        } catch (e) {
          print('Error extracting network filters: $e');
        }
      }
    }
    return [];
  }

  static String _generateNetworkBlockingScript(List<String> networkFilters) {
    if (networkFilters.isEmpty) return '';

    // Using JavaScript code that avoids ES6 syntax and uses standard ES5 syntax
    final encodedFilters = json.encode(networkFilters);

    return '''
      // Setup network request blocking
      (function() {
        // Create a list of blocked patterns
        var blockedPatterns = $encodedFilters;
        
        // Function to check if a URL matches any blocked pattern
        function shouldBlockRequest(url) {
          for (var i = 0; i < blockedPatterns.length; i++) {
            var pattern = blockedPatterns[i];
            
            if (pattern.indexOf('||') === 0) {
              var domainPart = pattern.substring(2);
              if (url.indexOf(domainPart) !== -1) return true;
            } 
            else if (pattern.indexOf('|http') === 0) {
              var startPattern = pattern.substring(1);
              if (url.indexOf(startPattern) === 0) return true;
            } 
            else {
              // Simple substring matching
              var cleanPattern = pattern.replace(/[\\^\$]/g, '');
              if (url.indexOf(cleanPattern) !== -1) return true;
            }
          }
          return false;
        }
        
        // Create XHR proxy
        var originalXHR = window.XMLHttpRequest;
        
        function XHRProxy() {
          var xhr = new originalXHR();
          var originalOpen = xhr.open;
          var self = this;
          
          xhr.open = function(method, url) {
            if (shouldBlockRequest(url)) {
              // Block request by diverting to empty response
              console.log('[AdBlock] Blocked XHR request:', url);
              
              // Set properties
              this.readyState = 4;
              this.status = 0;
              this.statusText = 'Error';
              this.responseText = '';
              this.response = '';
              
              // Create event handlers response
              var onReadyStateChangeHandler = this.onreadystatechange;
              var onErrorHandler = this.onerror;
              
              // Defer execution but don't actually make request
              setTimeout(function() {
                if (onReadyStateChangeHandler) onReadyStateChangeHandler.call(self);
                if (onErrorHandler) onErrorHandler.call(self, new Error('Blocked by AdBlock'));
              }, 0);
              
              return;
            }
            
            // Normal request
            return originalOpen.apply(this, arguments);
          };
          
          return xhr;
        }
        
        // Replace XMLHttpRequest
        window.XMLHttpRequest = XHRProxy;
        
        // Intercept fetch requests if supported
        if (window.fetch) {
          var originalFetch = window.fetch;
          window.fetch = function(resource, init) {
            var url = resource;
            if (typeof resource === 'object' && resource.url) {
              url = resource.url;
            }
            
            if (typeof url === 'string' && shouldBlockRequest(url)) {
              console.log('[AdBlock] Blocked fetch request:', url);
              return new Promise(function(resolve) {
                resolve(new Response('', { status: 0, statusText: 'Blocked' }));
              });
            }
            
            return originalFetch.apply(this, arguments);
          };
        }
      })();
    ''';
  }

  static String _getBasicAdBlockScript() {
    return '''
      function applyBasicAdBlock() {
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
          'iframe[src*="googlesyndication"]',
            'iframe[src*="ad."]',
            
            // Banners and popups
            '.banner-ads', '#banner-ads',
            '.google-ads', '#google-ads',
            'div[class*="banner"]', 'div[id*="banner"]',
            'div[class*="popup"]', 'div[id*="popup"]',
            
            // Social widgets and tracking
            '.social-share', '.share-buttons',
            '[class*="tracking"]', '[id*="tracking"]',
            
          // Additional specific selectors for Hako and docln
            '.quangcao', '#quangcao',
            '.ads-container', '.ads-wrapper',
          '[class*="sponsor"]', '[id*="sponsor"]',
          '#divAds', '.divAds',
          '#adsbox', '.adsbox',
          '#ads-holder', '.ads-holder'
          ];

        // Apply common selectors in a single operation if possible
        try {
          const elements = document.querySelectorAll(commonAdSelectors.join(', '));
          elements.forEach(function(element) { element.remove(); });
        } catch (e) {
          // Fall back to individual selectors if combined fails
          commonAdSelectors.forEach(function(selector) {
            try {
              document.querySelectorAll(selector).forEach(function(element) {
              element.remove();
            });
            } catch (err) {
              // Silently fail for invalid selectors
            }
          });
        }

        // Remove scripts with ad-related keywords
          const scripts = document.getElementsByTagName('script');
        const adKeywords = /(adsbygoogle|googleads|pagead2|advertisement|analytics|tracking|gtag|adsense)/i;
        for (let i = scripts.length-1; i >= 0; i--) {
          const script = scripts[i];
          if (script.src && script.src.match(adKeywords) || 
              script.innerHTML && script.innerHTML.match(adKeywords)) {
              script.remove();
            }
          }

          // Clean iframes
        document.querySelectorAll('iframe').forEach(function(iframe) {
          if (iframe.src && iframe.src.match(/(ads|analytics|tracking|doubleclick)/i)) {
              iframe.remove();
            }
          });
        
        // Block popups
        window.open = function(url, name, params) {
          // Allow only specific popups (if needed in the future)
          // For now, block all popups
          console.log('Popup blocked');
          return null;
        };

        // Clean up ad-related inline styles
        document.querySelectorAll('[style*="z-index: 9999"], [style*="position: fixed"]').forEach(function(el) {
          if (el.clientHeight < 50 || el.clientWidth < 50 || 
              el.clientHeight > window.innerHeight * 0.7 || 
              el.clientWidth > window.innerWidth * 0.7) {
            el.remove();
          }
        });
        
        // Handle sticky notification banners
        document.querySelectorAll('[class*="cookie"], [class*="consent"], [class*="notification"], [class*="alert"]').forEach(function(el) {
          if (el.style.position === 'fixed' || window.getComputedStyle(el).position === 'fixed') {
            el.remove();
          }
        });
        
        // Detect and remove floating elements
        const detectOverlayAds = function() {
          document.querySelectorAll('body > div').forEach(function(div) {
            const style = window.getComputedStyle(div);
            if ((style.position === 'fixed' || style.position === 'absolute') && 
                (parseInt(style.zIndex) > 1000 || style.zIndex === 'auto') &&
                !div.querySelector('input, button')) {
              div.remove();
            }
          });
        };
        
        // Run overlay detection
        detectOverlayAds();
        setTimeout(detectOverlayAds, 2000);
      }
      
      applyBasicAdBlock();
    ''';
  }
}
