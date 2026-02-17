class SourceHostGroupHelper {
  const SourceHostGroupHelper._();

  // 常见多段公共后缀；用于近似主域名分组。
  static const Set<String> _multiPartPublicSuffixes = <String>{
    'ac.cn',
    'com.cn',
    'edu.cn',
    'gov.cn',
    'net.cn',
    'org.cn',
    'com.hk',
    'com.tw',
    'com.au',
    'net.au',
    'org.au',
    'co.jp',
    'co.kr',
    'co.uk',
    'org.uk',
    'gov.uk',
    'ac.uk',
  };

  static String groupHost(String url) {
    final uri = Uri.tryParse(url);
    final host = (uri?.host ?? '').trim().toLowerCase();
    if (host.isEmpty) return '#';

    // IPv4/IPv6 直接按原 host 分组。
    final isIpv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
    if (isIpv4 || host.contains(':')) return host;

    final labels = host.split('.').where((e) => e.isNotEmpty).toList();
    if (labels.length <= 2) return host;

    final tail2 = '${labels[labels.length - 2]}.${labels.last}';
    if (_multiPartPublicSuffixes.contains(tail2) && labels.length >= 3) {
      return '${labels[labels.length - 3]}.$tail2';
    }

    return tail2;
  }
}
