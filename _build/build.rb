require 'uri'
# encoding: utf-8
# Corner Site Co. premium draft generator.
# ruby build.rb  ->  out/<dir>/<slug>/index.html
# Rules: only verified facts for real businesses; photos are Unsplash (free licence)
# placeholders, labelled; real drafts carry the draft banner + noindex.
require 'json'; require 'cgi'; require 'erb'; require 'fileutils'
ROOT = __dir__
THEMES = JSON.parse(File.read(File.join(ROOT, 'themes.json'), encoding: 'UTF-8'))
SITES  = JSON.parse(File.read(File.join(ROOT, 'sites.json'), encoding: 'UTF-8'))
FOUNDING = JSON.parse(File.read(File.join(ROOT, 'founding.json'), encoding: 'UTF-8'))['spots_left'].to_i
OTTAWA_RE = /,\s*ON\b|Ontario|Ottawa|Orl[ée]ans|Vanier|Gloucester|Barrhaven|Kanata|Nepean|Manotick|Blackburn|Cumberland|Stittsville/i
HOME = 'https://cornersiteco.ca/'
LAYOUT_BY_THEME = {'auto'=>'bold','detailing'=>'bold','barber'=>'bold','tattoo'=>'bold','pub'=>'bold','gold'=>'bold','clinic'=>'split','law'=>'split','electric'=>'split','grocery'=>'split','thrift'=>'split','salon'=>'editorial','tacos'=>'editorial','ethiopian'=>'editorial','italian'=>'editorial','bakery'=>'editorial','cafe'=>'editorial'}

ICONS = {
  'gauge'=>'<path d="M12 14l4-4"/><path d="M3.3 17a9 9 0 1 1 17.4 0"/><circle cx="12" cy="14" r="1.5"/>',
  'disc'=>'<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3"/><path d="M12 3v3M21 12h-3M12 21v-3M3 12h3"/>',
  'drop'=>'<path d="M12 3s6 6.5 6 11a6 6 0 0 1-12 0c0-4.5 6-11 6-11z"/>',
  'tire'=>'<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4"/><path d="M12 3v5M12 16v5M3 12h5M16 12h5"/>',
  'sparkle'=>'<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/><path d="M19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z"/>',
  'seat'=>'<path d="M7 4h6a2 2 0 0 1 2 2v7H7z"/><path d="M5 13h12l2 5H5z"/><path d="M7 18v3M17 18v3"/>',
  'car'=>'<path d="M5 16l1.5-5A2 2 0 0 1 8.4 9.5h7.2a2 2 0 0 1 1.9 1.5L19 16"/><path d="M3 16h18v3H3z"/><circle cx="7.5" cy="19" r="1.5"/><circle cx="16.5" cy="19" r="1.5"/>',
  'phone'=>'<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z"/>',
  'scissors'=>'<circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><path d="M20 4L8.1 15.9M14.5 14.5L20 20M8.1 8.1L12 12"/>',
  'razor'=>'<path d="M4 20l7-7"/><rect x="10" y="3" width="11" height="7" rx="1.5" transform="rotate(45 15.5 6.5)"/>',
  'comb'=>'<path d="M3 8h18v4H3z"/><path d="M5 12v6M8 12v6M11 12v6M14 12v6M17 12v6M20 12v6"/>',
  'star'=>'<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>',
  'flame'=>'<path d="M12 3c1 4 5 5.5 5 10a5 5 0 0 1-10 0c0-2 1-3.5 2-4.5 0 2 1 3 2 3 0-3-1-5 1-8.5z"/>',
  'utensils'=>'<path d="M7 3v8a2 2 0 0 0 4 0V3M9 3v18M17 3c-2 2-2.5 5-2.5 7.5S16 13 17 13v8"/>',
  'bowl'=>'<path d="M3 11h18a9 9 0 0 1-18 0z"/><path d="M8 7c0-1.5 1-2 1-3.5M12 7c0-1.5 1-2 1-3.5M16 7c0-1.5 1-2 1-3.5"/>',
  'leaf'=>'<path d="M5 19C5 10 11 4 20 4c0 9-6 15-15 15z"/><path d="M5 19l8-8"/>',
  'users'=>'<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><circle cx="17" cy="9" r="2.5"/><path d="M16 14.2a5 5 0 0 1 6 4.8"/>',
  'bag'=>'<path d="M5 8h14l-1 13H6z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/>',
  'bread'=>'<path d="M4 12a5 5 0 0 1 3-9h10a5 5 0 0 1 3 9v8H4z"/><path d="M9 12v4M15 12v4"/>',
  'camera'=>'<rect x="3" y="7" width="18" height="13" rx="2"/><circle cx="12" cy="13.5" r="3.5"/><path d="M8 7l1.5-3h5L16 7"/>',
  'knife'=>'<path d="M3 21l9-9"/><path d="M12 12c3-3 6-9 9-9-1 4-4 9-7 11z"/>',
  'cart'=>'<path d="M3 4h2l2.5 11h11L21 8H6.5"/><circle cx="9" cy="19.5" r="1.5"/><circle cx="17" cy="19.5" r="1.5"/>',
  'bolt'=>'<path d="M13 2L4 14h7l-1 8 9-12h-7z"/>',
  'plug'=>'<path d="M9 3v5M15 3v5M6 8h12v3a6 6 0 0 1-12 0z"/><path d="M12 17v4"/>',
  'bulb'=>'<path d="M9 18h6M10 21h4"/><path d="M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0 0 12 3z"/>',
  'pen'=>'<path d="M4 20l4-1L19 8l-3-3L5 16z"/><path d="M14 7l3 3"/>',
  'eye'=>'<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  'shirt'=>'<path d="M8 3l4 2 4-2 5 4-3 3-2-1v12H8V9l-2 1-3-3z"/>',
  'gem'=>'<path d="M6 3h12l4 6-10 12L2 9z"/><path d="M2 9h20M9 3L7 9l5 12 5-12-2-6"/>',
  'moon'=>'<path d="M20 14.5A8.5 8.5 0 0 1 9.5 4 8.5 8.5 0 1 0 20 14.5z"/>',
  'cup'=>'<path d="M4 8h13v6a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5z"/><path d="M17 10h1.5a2.5 2.5 0 0 1 0 5H17"/><path d="M8 3v2M12 3v2"/>',
  'pin'=>'<path d="M12 21s7-6.2 7-12A7 7 0 0 0 5 9c0 5.8 7 12 7 12z"/><circle cx="12" cy="9" r="2.5"/>',
  'clock'=>'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  'mail'=>'<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/>',
  'arrow'=>'<path d="M5 12h14M13 6l6 6-6 6"/>'
}
def icon(n, s=22)
  %(<svg width="#{s}" height="#{s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">#{ICONS[n] || ICONS['star']}</svg>)
end
def e(s)
  CGI.escapeHTML(s.to_s)
end
def img(id, w)
  # client photos: a URL, an absolute/relative path, or a filename with an image extension
  return id if id.to_s =~ %r{\A(https?:|/|\./)} || id.to_s =~ /\.(jpe?g|png|webp|avif)\z/i
  "https://images.unsplash.com/photo-#{id}?auto=format&fit=crop&w=#{w}&q=80"
end
# LocalBusiness JSON-LD for FINAL client sites only (no aggregateRating: self-published ratings are ignored by Google)
def local_business_ld(s)
  addr = s['address'].to_s
  parts = addr.split(',').map(&:strip)
  region = addr[/\b(ON|QC|BC|AB|MB|SK|NS|NB|NL|PE|YT|NT|NU)\b/] || 'ON'
  postal = addr[/[A-Z]\d[A-Z] ?\d[A-Z]\d/]
  photo = img(Array(s['photos']).first.to_s, 1200)
  photo = URI.join(s['canonical'].to_s, photo).to_s if s['canonical'] && photo !~ %r{\Ahttps?:}
  h = { '@context' => 'https://schema.org', '@type' => 'LocalBusiness', 'name' => s['name'] }
  h['url'] = s['canonical'] if s['canonical']
  h['telephone'] = s['tel'] if s['tel'].to_s != ''
  h['email'] = s['email'] if s['email'].to_s != ''
  h['image'] = photo unless photo.to_s.empty?
  if parts.size >= 2
    a = { '@type' => 'PostalAddress', 'streetAddress' => parts.first, 'addressLocality' => parts[-2].sub(/\s*\b#{region}\b.*/, '').strip, 'addressRegion' => region, 'addressCountry' => 'CA' }
    a['postalCode'] = postal if postal
    h['address'] = a
  end
  h['sameAs'] = s['same_as'] if s['same_as']
  JSON.generate(h).gsub('<', '\u003c')
end

def stars(r)
  v = r.to_f
  (1..5).map { |i| f = [[v - (i - 1), 0].max, 1].min; %(<span class="st" style="--f:#{(f * 100).round}%">★</span>) }.join
end
def poss(n) n.end_with?('s') ? "#{n}'" : "#{n}'s" end
def gfont(name, w)
  name.gsub(' ', '+') + ":wght@#{w}"
end

TPL = ERB.new(File.read(File.join(ROOT, 'template.html.erb'), encoding: 'UTF-8'), trim_mode: '-')
SITES.each do |s|
  t = THEMES.fetch(s['theme'])
  maps = 'https://www.google.com/maps/search/?api=1&query=' + ERB::Util.url_encode("#{s['name']} #{s['address']}")
  embed = 'https://maps.google.com/maps?q=' + ERB::Util.url_encode(s['sample'] ? 'Ottawa, ON' : "#{s['name']}, #{s['address']}") + '&z=15&output=embed'
  primary_href = s['cta'] == 'email' ? "mailto:#{s['email']}" : "tel:#{s['tel']}"
  book = s['book_url'].to_s.strip.empty? ? nil : s['book_url']
  founding = FOUNDING > 0 && !!(s['address'].to_s =~ OTTAWA_RE)
  alt_txt = s['final'] ? s['name'] : (s['sample'] ? 'Sample photo' : "Placeholder photo for #{s['name']}")
  hero_cta = if book
    %(<a class="btn btn-p" href="#{e book}" target="_blank" rel="noopener">#{icon('clock', 20)}#{e(s['book_label'] || 'Book online')}</a>)
  else
    %(<a class="btn btn-p" href="#{primary_href}">#{icon(s['cta'] == 'email' ? 'mail' : 'phone', 20)}#{e s['cta_label']}</a>)
  end
  out = File.join(ROOT, 'out', s['dir'], s['slug']); FileUtils.mkdir_p(out)
  File.write(File.join(out, 'index.html'), TPL.result(binding))
  puts "built #{s['dir']}/#{s['slug']}"
end
