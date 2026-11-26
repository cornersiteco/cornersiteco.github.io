# encoding: utf-8
# Corner Site Co. draft generator, v4 ("art directions").
#   ruby build.rb                      -> out/<dir>/<slug>/index.html for every entry in sites.json
#   ONLY=slug-a,slug-b ruby build.rb   -> only those slugs
# Rules (unchanged): only verified facts for real businesses; photos are Unsplash (free licence)
# placeholders, labelled; real drafts carry the draft banner + noindex.
# Files: template.html.erb (shell), base.css, layouts/<art>.html.erb + layouts/<art>.css, themes.json (arts + palettes).
#
# ---------- BRAND MATCHING (optional, per site) ----------
# A draft should look like the client's own brand, not like one of our palettes. Add to a sites.json entry:
#
#   "brand": {
#     "accent": "#c8102e",              the brand colour (buttons, links, highlights)
#     "ink": "#1a1a1a",                 main text colour
#     "bg": "#fffaf3",                  page background (a dark value gives a dark page)
#     "display_font": "Playfair Display",   Google Font for the name and headings
#     "body_font": "Inter",                 Google Font for everything else
#     "logo_case": "upper"              how the name is set: upper | title | lower   (title = exactly as written in "name")
#   }
#
# Every key is optional; anything left out keeps the art direction's own value. Every layout honours all six.
#   Colours   #rgb or #rrggbb. paper / muted / line / button-text colours are derived from the three you give.
#             WCAG AA (4.5:1) is enforced at build time, and each fix is logged as "WARN brand <slug>: ...":
#               - ink on bg below 4.5:1      -> ink falls back to near-black or white, whichever reads better
#               - accent as TEXT on bg/paper -> the fill keeps the true brand colour; text uses a shade of it nudged
#                                               toward ink until it passes (CSS var --at). Example: gold links on cream.
#               - text on accent (buttons)   -> white if it passes, otherwise near-black
#               - an unreadable value ("red", "#12") is ignored with a warning
#             A supplied accent also becomes the colour of the main button in every layout.
#   Fonts     loaded from Google Fonts only when set (the layout font they replace is no longer requested).
#             Families in BRAND_FONTS get their proper weights/italics; any other family is requested as plain
#             "family=Name" (regular only) with a warning. To ask for exact axes write it the themes.json way:
#             "display_font": "Rozha One"  or  "display_font": "Bitter:ital,wght@0,400..700;1,400".
#             Each brand font gets its own <link>, so a mistyped family can only lose itself, never the page's other fonts.
#             Fake bold/italic is switched off for brand fonts: a missing style falls back to the real upright cut.
#             Optional extra: "display_weight": 700 forces the weight of the name and section headings.
#             A wide brand font never overflows: a few lines of inline JS shrink the name to fit (poster: re-fit exactly).
#   Preview   NOBRAND=1 ruby build.rb builds everything with the brand blocks ignored (for before/after checks).
require 'uri'; require 'json'; require 'cgi'; require 'erb'; require 'fileutils'; require 'zlib'
ROOT = __dir__
THEMES = JSON.parse(File.read(File.join(ROOT, 'themes.json'), encoding: 'UTF-8'))
ARTS = THEMES.fetch('arts')
SITES  = JSON.parse(File.read(File.join(ROOT, ENV['SITES'] || 'sites.json'), encoding: 'UTF-8'))
FOUNDING = JSON.parse(File.read(File.join(ROOT, 'founding.json'), encoding: 'UTF-8'))['spots_left'].to_i
OTTAWA_RE = /,\s*ON\b|Ontario|Ottawa|Orl[ée]ans|Vanier|Gloucester|Barrhaven|Kanata|Nepean|Manotick|Blackburn|Cumberland|Stittsville/i
HOME = 'https://cornersiteco.ca/'

# ---------- small helpers ----------
def e(s) CGI.escapeHTML(s.to_s) end
def blank?(x) x.nil? || x.to_s.strip.empty? end
def poss(n) n.end_with?('s') ? "#{n}'" : "#{n}'s" end
def img(id, w)
  # client photos: a URL, an absolute/relative path, or a filename with an image extension
  return id if id.to_s =~ %r{\A(https?:|/|\./)} || id.to_s =~ /\.(jpe?g|png|webp|avif)\z/i
  "https://images.unsplash.com/photo-#{id}?auto=format&fit=crop&w=#{w}&q=80"
end
def srcset(id, widths)
  return nil if img(id, 1) == id
  widths.map { |w| "#{img(id, w)} #{w}w" }.join(', ')
end
ICONS = {
  'phone'=>'<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z"/>',
  'pin'=>'<path d="M12 21s7-6.2 7-12A7 7 0 0 0 5 9c0 5.8 7 12 7 12z"/><circle cx="12" cy="9" r="2.5"/>',
  'clock'=>'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  'mail'=>'<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/>',
  'arrow'=>'<path d="M5 12h14M13 6l6 6-6 6"/>',
  'book'=>'<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/>',
  'bag'=>'<path d="M6 8h12l1 12H5L6 8z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/>'
}
def icon(n, s = 18)
  %(<svg width="#{s}" height="#{s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">#{ICONS[n] || ICONS['arrow']}</svg>)
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
  JSON.generate(h).gsub('<', '<')
end

def stars(r)
  v = r.to_f
  (1..5).map { |i| f = [[v - (i - 1), 0].max, 1].min; %(<span class="st" style="--f:#{(f * 100).round}%">★</span>) }.join
end

# ---------- colour maths (WCAG 2.x) ----------
def hex_rgb(h)
  m = h.to_s.strip.match(/\A#?(\h{3}|\h{6})\z/) or return nil
  x = m[1]; x = x.chars.map { |c| c * 2 }.join if x.size == 3
  x.scan(/../).map { |c| c.to_i(16) }
end
def rgb_hex(c) '#' + c.map { |v| '%02x' % [[v.round, 0].max, 255].min }.join end
def lum(c) r, g, b = c.map { |v| v /= 255.0; v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055)**2.4 }; 0.2126 * r + 0.7152 * g + 0.0722 * b end
def contrast(a, b) x, y = [lum(a), lum(b)].sort; (y + 0.05) / (x + 0.05) end
def mix(a, b, t) a.zip(b).map { |x, y| x + (y - x) * t } end   # t = 0 -> a, t = 1 -> b
AA = 4.5
NEAR_BLACK = [17, 17, 17]; WHITE = [255, 255, 255]
def best_text_on(bg) contrast(WHITE, bg) >= contrast(NEAR_BLACK, bg) ? WHITE : NEAR_BLACK end
# move colour c toward `to` in small steps until it reads at AA on every background given
def until_aa(c, to, bgs)
  0.step(1, 0.04) { |t| x = mix(c, to, t); return x if bgs.all? { |b| contrast(x, b) >= AA } }
  to
end

# ---------- brand: sites.json "brand" -> palette + fonts (see the header of this file) ----------
BRAND_FONTS = {   # Google Fonts axes that exist for each family (all checked against the css2 API)
  'Abril Fatface'=>'', 'Alfa Slab One'=>'', 'Anton'=>'', 'Archivo'=>'wght@400;500;600;700;800', 'Archivo Black'=>'', 'Barlow'=>'wght@400;500;600;700',
  'Barlow Condensed'=>'wght@500;600;700', 'Bebas Neue'=>'', 'Big Shoulders Display'=>'wght@500;600;700;800', 'Bodoni Moda'=>'ital,opsz,wght@0,6..96,400..700;1,6..96,400..600',
  'Bricolage Grotesque'=>'opsz,wght@12..96,400;12..96,500;12..96,600;12..96,700', 'Cinzel'=>'wght@400;500;600;700', 'Cormorant'=>'ital,wght@0,400..700;1,400..700',
  'Cormorant Garamond'=>'ital,wght@0,400;0,500;0,600;1,400;1,500', 'DM Sans'=>'opsz,wght@9..40,400;9..40,500;9..40,600;9..40,700', 'DM Serif Display'=>'ital@0;1',
  'Dancing Script'=>'wght@400;500;600;700', 'Epilogue'=>'wght@400;500;600;700', 'Familjen Grotesk'=>'wght@400;500;600;700', 'Figtree'=>'wght@400;500;600;700',
  'Fraunces'=>'ital,opsz,wght@0,9..144,400..800;1,9..144,400..600', 'Gloock'=>'', 'Great Vibes'=>'', 'Instrument Sans'=>'wght@400;500;600;700', 'Instrument Serif'=>'ital@0;1',
  'Inter'=>'wght@400;500;600;700', 'Italiana'=>'', 'Josefin Sans'=>'wght@400;500;600;700', 'Jost'=>'wght@400;500;600;700', 'Kanit'=>'wght@400;500;600;700', 'Karla'=>'wght@400;500;600;700',
  'Lato'=>'wght@400;700', 'League Spartan'=>'wght@400;500;600;700', 'Lexend'=>'wght@400;500;600;700', 'Libre Baskerville'=>'ital,wght@0,400;0,700;1,400',
  'Libre Franklin'=>'wght@400;500;600;700', 'Lora'=>'ital,wght@0,400..700;1,400..700', 'Manrope'=>'wght@400;500;600;700;800', 'Marcellus'=>'', 'Montserrat'=>'wght@400;500;600;700;800',
  'Mulish'=>'wght@400;500;600;700', 'Newsreader'=>'ital,opsz,wght@0,6..72,400..700;1,6..72,400..600', 'Nunito'=>'wght@400;500;600;700;800', 'Nunito Sans'=>'wght@400;600;700',
  'Open Sans'=>'wght@400;500;600;700', 'Oswald'=>'wght@400;500;600;700', 'Outfit'=>'wght@400;500;600;700', 'Pacifico'=>'', 'Permanent Marker'=>'',
  'Playfair Display'=>'ital,wght@0,400..800;1,400..600', 'Plus Jakarta Sans'=>'wght@400;500;600;700', 'Poppins'=>'wght@400;500;600;700', 'Prata'=>'', 'Quicksand'=>'wght@400;500;600;700',
  'Raleway'=>'wght@400;500;600;700', 'Red Hat Display'=>'wght@400;500;600;700;800', 'Righteous'=>'', 'Roboto'=>'wght@400;500;700', 'Rubik'=>'wght@400;500;600;700', 'Sora'=>'wght@400;500;600;700',
  'Source Serif 4'=>'ital,opsz,wght@0,8..60,400..700;1,8..60,400', 'Space Grotesk'=>'wght@400;500;600;700', 'Syne'=>'wght@400;500;600;700;800', 'Teko'=>'wght@400;500;600;700',
  'Tenor Sans'=>'', 'Unbounded'=>'wght@400;500;600;700', 'Urbanist'=>'wght@400;500;600;700', 'Work Sans'=>'wght@400;500;600;700', 'Yeseva One'=>'', 'Zilla Slab'=>'wght@400;500;600;700'
}
ART_FALLBACK = {'atelier'=>'"Didot","Bodoni 72",Georgia,serif', 'gazette'=>'"Iowan Old Style",Georgia,serif', 'poster'=>'"Haettenschweiler","Arial Narrow",Impact,sans-serif', 'menu'=>'"Iowan Old Style",Georgia,serif', 'spec'=>'"Arial Narrow",system-ui,sans-serif', 'gallery'=>'system-ui,-apple-system,"Segoe UI",sans-serif'}
BRAND_WARN = []
def brand_warn(slug, msg) BRAND_WARN << "WARN brand #{slug}: #{msg}"; warn BRAND_WARN.last end
# "Playfair Display" or "Bitter:wght@400;700" -> [css family name, Google Fonts css2 family spec] (nil when not usable)
def brand_font(slug, v, key)
  return nil if blank?(v)
  name, axes = v.to_s.strip.split(':', 2)
  name = name.strip.gsub(/\s+/, ' ')
  unless name =~ /\A[A-Za-z0-9 ]+\z/
    brand_warn(slug, %(#{key} "#{v}" is not a Google Font family name; keeping the layout font)); return nil
  end
  if axes.nil?
    known = BRAND_FONTS.find { |k, _| k.casecmp?(name) }
    if known then name, axes = known
    else brand_warn(slug, %(#{key} "#{name}" is not in BRAND_FONTS; loading the regular cut only (write "#{name}:wght@400;600" to ask for more)))
    end
  end
  [name, blank?(axes) ? name : "#{name}:#{axes}"]
end
# base = the art direction's palette (hash of CSS colours). Returns [palette, text-accent hex].
def brand_palette(slug, base, b)
  col = lambda { |k|
    next nil if blank?(b[k])
    hex_rgb(b[k]) || (brand_warn(slug, %(#{k} "#{b[k]}" is not a #rgb / #rrggbb colour; keeping the layout colour)); nil)
  }
  bg = col.('bg'); ink = col.('ink'); accent = col.('accent')
  p = base.dup
  own_bg = bg || hex_rgb(base['bg']); own_ink = ink || hex_rgb(base['ink'])
  if contrast(own_ink, own_bg) < AA
    safe = best_text_on(own_bg)
    brand_warn(slug, "ink #{rgb_hex(own_ink)} on bg #{rgb_hex(own_bg)} is #{'%.2f' % contrast(own_ink, own_bg)}:1 (needs 4.5); text falls back to #{rgb_hex(safe)}")
    own_ink = safe
  end
  if bg || ink
    dark = lum(own_bg) < 0.18
    paper = dark ? mix(own_bg, WHITE, 0.07) : mix(own_bg, WHITE, 0.62)
    p['bg'] = rgb_hex(own_bg); p['ink'] = rgb_hex(own_ink); p['paper'] = rgb_hex(paper)
    p['muted'] = rgb_hex(until_aa(mix(own_ink, own_bg, 0.36), own_ink, [own_bg, paper]))
    p['line'] = "rgba(#{own_ink.map(&:round).join(',')},#{dark ? '.2' : '.15'})"
    dark ? p['dark'] = true : p.delete('dark')
  end
  paper = hex_rgb(p['paper']) || own_bg
  acc = accent || hex_rgb(base['accent'])
  if accent
    p['accent'] = rgb_hex(acc)
    on = contrast(WHITE, acc) >= AA ? WHITE : best_text_on(acc)
    brand_warn(slug, "white on accent #{rgb_hex(acc)} is #{'%.2f' % contrast(WHITE, acc)}:1; button text uses #{rgb_hex(on)}") unless on == WHITE
    p['on'] = rgb_hex(on)
  end
  at = acc
  unless [own_bg, paper].all? { |x| contrast(acc, x) >= AA }
    at = until_aa(acc, own_ink, [own_bg, paper])
    worst = [own_bg, paper].min_by { |x| contrast(acc, x) }
    brand_warn(slug, "accent #{rgb_hex(acc)} as text on #{worst == own_bg ? 'bg' : 'card background'} #{rgb_hex(worst)} is #{'%.2f' % contrast(acc, worst)}:1 (needs 4.5); accent-coloured text uses #{rgb_hex(at)}, fills keep the brand colour") if accent || bg
  end
  p['at'] = rgb_hex(at)
  p
end

# typographic apostrophes and quotes for visible text (never for attributes, URLs or the copy button)
def smart(s)
  s.to_s.gsub(/(?<=[[:alpha:].,!?])'/, "\u2019").gsub(/(?<=\d)'(?=[[:alpha:]])/, "\u2019").gsub(/'(?=\d0s\b)/, "\u2019")   # it's, Kids', 2023's, '90s
   .gsub(/(?<![[:alnum:]])"(?=\S)/, "\u201C").gsub(/(?<=[^\s\d])"/, "\u201D").gsub(/(?<![[:alnum:]])'(?=\S)/, "\u2018")   # 18" and 5' stay straight (inches, feet)
end
def tx(s) CGI.escapeHTML(smart(s)) end

# ---------- art direction choice ----------
# 1) sites.json "art" (or "layout" if it already holds a v4 name); 2) niche words in the kicker; 3) the old theme.
NICHE_ART = [
  [/nail|lash|brow|tattoo|piercing|detailing|makeup|jewell/i, 'gallery'],
  [/barber/i, 'poster'],
  [/caf[eé]|coffee|bakery|bake|patisserie|grocery|butcher|deli|ice cream|donut|tea\b/i, 'menu'],
  [/restaurant|kitchen|pub\b|(?<!beauty )(?<!brow )(?<!lash )(?<!nail )(?<!blow-dry )bar\b|grill|pizza|taco|cuisine|diner|bistro|eatery|sushi|shawarma|food/i, 'gazette'],
  [/auto|mechanic|tire|electric|plumb|hvac|roof|contract|garage|repair|landscap|pawn|gold buying/i, 'spec'],
  [/hair|salon|spa|beauty|wax|esthet|skin|groom|clinic|law|tailor|veterin|wellness|thrift/i, 'atelier']
]
THEME_ART = {'auto'=>'spec','detailing'=>'gallery','electric'=>'spec','barber'=>'poster','tattoo'=>'gallery','salon'=>'atelier','clinic'=>'atelier','law'=>'atelier','gold'=>'atelier','thrift'=>'atelier','tacos'=>'gazette','ethiopian'=>'gazette','italian'=>'gazette','pub'=>'gazette','bakery'=>'menu','cafe'=>'menu','grocery'=>'menu'}
def art_for(s)
  return s['art'] if ARTS.key?(s['art'])
  return s['layout'] if ARTS.key?(s['layout'])
  k = s['kicker'].to_s.split(' · ').first.to_s
  return 'atelier' if k =~ /beauty (bar|lounge)/i
  NICHE_ART.each { |re, a| return a if k =~ re }
  THEME_ART[s['theme']] || 'atelier'
end
def seed(s, salt = '') Zlib.crc32(s['slug'].to_s + salt) end

# ---------- QA10: honest placeholders ----------
# A placeholder photo may show the craft or the product in close-up. It may never show another business:
# no storefronts, signs, readable branding or staff faces (PHOTO_NEVER), and on real drafts no other shop's
# interior either (PHOTO_INTERIOR; fine on fictional samples). A page with fewer photos is better than a page
# with a wrong one: every layout works with 0 to 4 photos and never repeats one.
PHOTO_NEVER = %w[1631720040176-0d789a643a78 1759662232622-6c0754a379f4 1517701986616-711a9d625afe 1777904257871-13b96905467e 1761839256791-6a93f89fb8b0 1770836037793-95bdbf190f71 1621905251189-08b45d6a269e 1621905251918-48416bd8575a 1758225490983-0fae7961e425 1584873069262-427e437b8eb4 1767491654834-13bf58ed9522 1784807739590-ddb4704d30dc 1758518731462-d091b0b4ed0d 1774072411106-81c586a56e9b 1777714219991-36d4ff2fe541 1583665354191-634609954d54 1771308354374-3d9ad8970483 1760877611905-0f885a3ce551]
PHOTO_INTERIOR = %w[1585747860715-2ba37e788b70 1560066984-138dadb4c035 1600948836101-f9ffda59d250 1695527081848-1e46c06e6458 1764448726322-2abd2bdd6c68 1469631423273-6995642a6a40 1542181961-9590d0c79dab 1521590832167-7bcbfaa6381f 1552960226-639240203497 1497366754035-f200968a6e72 1505664063603-28e48ca204eb 1771154767182-d91ed5106636]
# hair-wash basins and salon chairs only belong on hair pages (they were showing up on nail and lash pages)
PHOTO_HAIR_ONLY = %w[1787651344170-c2f81514934d 1634449571010-02389ed0f9b0]
HAIR_TRADE = ->(t) { t =~ /hair|barber/i || (t =~ /salon|beauty/i && t !~ /nail|lash|brow|wax/i) }

# "Services" that are not services. ACTION ones repeat a button that is already on the page and are dropped;
# ASIDE ones are true, useful details ("Walk-ins welcome", "Cash only") and go in a short "Good to know" list.
SVC_ACTION = /\A(order online|book online|book ahead|online booking|easy booking|call to book|follow along|order|book)( now)?\z/i
SVC_ASIDE = /\A(a (calm|clean|cozy|cute|friendly|warm|welcoming) .+|ask about anything else|call ahead|order ahead|walk in or call ahead|out of town\?|caring stylists|cash only|chill vibes|clean (& cozy|studio)|clean, careful work|cozy home studio|easy visit|family atmosphere|flexible times|for the whole family|friendly team|good company|good value|hijab-friendly|kids welcome|kind, talented staff|last-minute.*|local|long-lasting (nails|results)|lashes that last|nail experts|natural products|open (7 days|late)|patient care|quiet & clean|relaxing atmosphere|right on .+|same-day appointments|something for everyone|steelton local|walk-ins( welcome| & bookings)?|your music)\z/i
RATING_H = /\A(\d[\d,]* (google )?reviews\b.*|\d\.\d stars from .+|rated \d\.\d .+|a perfect 5\.0.*)\z/i
FOOD_RE = /restaurant|kitchen|pub\b|(?<!beauty )(?<!brow )(?<!lash )(?<!nail )bar\b|grill|pizza|taco|cuisine|diner|bistro|caf|coffee|bakery|food|grocery|butcher|shawarma/i

# ---------- hours: parse "Mon–Fri 9 am – 6 pm · Sat 9–2 · Closed Sun" into a week, or nil ----------
DAYS = %w[Mon Tue Wed Thu Fri Sat Sun]
DAY_FULL = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday]
def day_idx(t) DAYS.index { |d| t.strip.downcase.start_with?(d.downcase) } end
def day_set(str)
  str = str.strip
  return (0..6).to_a if str =~ /\A(open )?(daily|every day|7 days( a week)?)\z/i
  return [5, 6] if str =~ /\Aweekends?\z/i
  return [0, 1, 2, 3, 4] if str =~ /\Aweekdays?\z/i
  out = []
  str.split(/\s*(?:,|&|\band\b)\s*/).each do |part|
    return nil if part.strip.empty?
    a, b = part.split(/\s*[–-]\s*/, 2)
    return nil unless a =~ /\A[A-Za-z]+\.?\z/ && (b.nil? || b =~ /\A[A-Za-z]+\.?\z/)
    i = day_idx(a); return nil unless i
    if b
      j = day_idx(b); return nil unless j
      k = i
      loop { out << k; break if k == j; k = (k + 1) % 7 }
    else
      out << i
    end
  end
  out.uniq
end
def tparse(t)
  m = t.strip.match(/\A(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)?\z/i)
  return nil unless m && m[1].to_i.between?(1, 12)
  [m[1].to_i, m[2].to_i, m[3] ? m[3].downcase.delete('.') : nil]
end
def to_min(h, mi, ap) (h % 12 + (ap == 'pm' ? 12 : 0)) * 60 + mi end
def range_parse(str)
  a, b = str.split(/\s*[–-]\s*/, 2); return nil unless a && b
  ta = tparse(a); tb = tparse(b); return nil unless ta && tb
  ha, ma, apa = ta; hb, mb, apb = tb
  if apa.nil? && apb.nil?      # "10–7": opens in the morning, closes in the afternoon
    apa = (ha >= 5 && ha < 12) ? 'am' : 'pm'; apb = 'pm'
  elsif apa.nil?               # "4–10 pm", "11–10 pm", "12 – 6 pm"
    apa = if apb == 'pm' then (ha == 12 || (ha < hb && hb != 12)) ? 'pm' : 'am' else (ha < hb ? 'am' : 'pm') end
  elsif apb.nil?
    apb = 'pm'
  end
  o = to_min(ha, ma, apa); c = to_min(hb, mb, apb)
  c += 1440 if c <= o && c <= 240   # closes after midnight
  return nil if c <= o
  [o, c]
end
def hours_parse(str)
  return nil if blank?(str) || str =~ /[()]/
  week = Array.new(7)
  str.split(/\s*·\s*/).each do |seg|
    seg = seg.strip
    if seg =~ /\Aclosed\s+(.+)\z/i || seg =~ /\A(.+?)\s+closed\z/i
      ds = day_set($1.gsub(/days?\b/i, '')) or return nil
      ds.each { |d| week[d] = :closed }
    elsif (m = seg.match(/\A(.*?[A-Za-z.])\s+(\d.*)\z/))
      ds = day_set(m[1]) or return nil
      r = range_parse(m[2]) or return nil
      ds.each { |d| week[d] = r }
    else
      return nil
    end
  end
  week.any? { |x| x.is_a?(Array) } ? week : nil
end
def fmt_t(min)
  min %= 1440; h = min / 60; m = min % 60
  ap = h < 12 ? 'am' : 'pm'; h12 = h % 12; h12 = 12 if h12 == 0
  m == 0 ? "#{h12} #{ap}" : "#{h12}:#{'%02d' % m} #{ap}"
end
TZ = {'ON'=>'America/Toronto','QC'=>'America/Toronto','MB'=>'America/Winnipeg','SK'=>'America/Regina','AB'=>'America/Edmonton','BC'=>'America/Vancouver','NS'=>'America/Halifax','NB'=>'America/Moncton','PE'=>'America/Halifax','NL'=>'America/St_Johns'}

# ---------- the name as a poster: balanced lines, each sized to fill the width (Anton caps advance widths, em) ----------
ANTON = Hash.new(0.49).merge('0'=>0.494,'1'=>0.331,'2'=>0.494,'3'=>0.494,'4'=>0.494,'5'=>0.494,'6'=>0.494,'7'=>0.494,'8'=>0.494,'9'=>0.494,'A'=>0.485,'B'=>0.479,'C'=>0.474,'D'=>0.493,'E'=>0.412,'F'=>0.399,'G'=>0.485,'H'=>0.499,'I'=>0.227,'J'=>0.466,'K'=>0.472,'L'=>0.397,'M'=>0.746,'N'=>0.498,'O'=>0.486,'P'=>0.472,'Q'=>0.494,'R'=>0.477,'S'=>0.461,'T'=>0.396,'U'=>0.474,'V'=>0.469,'W'=>0.712,'X'=>0.484,'Y'=>0.446,'Z'=>0.41,' '=>0.234,'&'=>0.52,'.'=>0.229,','=>0.236,"'"=>0.214,'’'=>0.232,'-'=>0.311,'/'=>0.405,'+'=>0.355,'!'=>0.229,'É'=>0.412,'È'=>0.412,'À'=>0.485,'Ç'=>0.474,'Ô'=>0.486) # measured in Chrome, em
def anton_w(t) t.upcase.each_char.map { |c| ANTON[c] }.sum end
def poster_lines(name, maxw)
  words = name.split(/\s+/)
  top = [words.size, 4].min
  best = nil
  (1..top).each do |n|
    (0...words.size - 1).to_a.combination(n - 1).each do |cuts|
      lines = []; prev = 0
      (cuts + [words.size - 1]).each { |c| lines << words[prev..c].join(' '); prev = c + 1 }
      ws = lines.map { |l| anton_w(l) }
      score = (ws.max - ws.min) + n * 0.5 + (ws.max > maxw ? 20 * (ws.max - maxw) : 0) + (ws.min < 3.2 && n > 1 ? 3 : 0)
      best = [score, lines] if best.nil? || score < best[0]
    end
  end
  best[1]
end
def poster_html(name, maxw, cls, kase = 'upper')
  poster_lines(name, maxw).map { |l| %(<span class="pl #{cls}" style="--w:#{anton_w(l).round(3)}">#{tx(kase == 'lower' ? l.downcase : (kase == 'title' ? l : l.upcase))}</span>) }.join
end

# ---------- per-site context ----------
class Ctx
  attr_reader :s, :art, :a, :pal, :pal_name, :v
  def initialize(s)
    @s = s
    @art = art_for(s); @a = ARTS.fetch(@art)
    names = @a['palettes'].keys
    allowed = (@a['palette_by_theme'] || {})[s['theme']] || @a['default_palettes'] || names
    @pal_name = names.include?(s['palette']) ? s['palette'] : allowed[seed(s, 'pal') % allowed.size]
    @brand = (ENV['NOBRAND'] || !s['brand'].is_a?(Hash)) ? {} : s['brand']
    base = @a['palettes'].fetch(@pal_name)
    @pal = brand_palette(s['slug'], base, @brand)
    @bfonts = [brand_font(s['slug'], @brand['display_font'], 'display_font'), brand_font(s['slug'], @brand['body_font'], 'body_font')]
    @kase = @brand['logo_case'].to_s.downcase
    unless @kase.empty? || %w[upper title lower].include?(@kase)
      brand_warn(s['slug'], %(logo_case "#{@brand['logo_case']}" is not upper, title or lower; ignored)); @kase = ''
    end
    @v = (s['variant'] || seed(s, 'v')).to_i % 3
    @week = hours_parse(s['hours'])
  end
  def final?; !!s['final'] end
  def sample?; !!s['sample'] end
  def draft?; !final? && !sample? end
  def name; s['name'] end
  def name_h; tx(name).gsub('-', '&#8209;').gsub(' &amp; ', '&nbsp;&amp; ') end   # ...and an ampersand never starts a line   # "Sari-Sari" never breaks at its hyphen
  # --- brand ---
  def brand?; !@brand.empty? end
  def brand_fonts?; @bfonts.any? end
  def logo_case; @kase end
  def poster_name(maxw) poster_html(name, maxw, '', @kase.empty? ? 'upper' : @kase) end
  # kicker parts that stay on one line each, so a line never breaks inside "Preston St"
  # When the whole kicker is longer than `max` characters it cannot fit one phone line: the parts then stack, one per line,
  # and the separators step aside (classes kb / ks, phones only), instead of leaving a dot dangling at a line end.
  def area_html(sep, max = 99)
    long = area_line.join('   ').size > max
    area_line.map { |x| %(<span class="nb#{long ? ' kb' : ''}">#{tx x}</span>) }.join(long ? sep.sub('<i ', '<i class="ks" ') : sep)
  end
  # CSS that must come after the layout's own :root (fonts, case, weight)
  def brand_css
    return '' unless brand?
    out = []
    v = []
    v << %(--fh:"#{@bfonts[0][0]}",#{ART_FALLBACK[@art]}) if @bfonts[0]
    v << %(--fb:"#{@bfonts[1][0]}",system-ui,-apple-system,"Segoe UI",sans-serif) if @bfonts[1]
    out << ":root{#{v.join(';')}}" unless v.empty?
    # a supplied brand colour is the colour of the main button, in every layout
    out << 'body.bf .act-p,body.bf .mbar .mp{background:var(--accent);border-color:var(--accent);color:var(--on)}body.bf .act-p:hover{background:var(--ink);border-color:var(--ink);color:var(--bg)}' unless blank?(@brand['accent'])
    out << 'h1,h2,h3,.lede,.hl,.deck,.drop,.where,.close a,.menu-cta a,.score .big{font-synthesis:none}' if @bfonts[0]
    out << 'body{font-synthesis:none}' if @bfonts[1] && @bfonts[1][1] !~ /wght/
    tt = { 'upper' => 'uppercase', 'lower' => 'lowercase', 'title' => 'none' }[@kase]
    out << "body.bf .name,body.bf .plate,body.bf .brand,body.bf .sbar .id{text-transform:#{tt}#{tt == 'uppercase' ? ';letter-spacing:.01em' : ''}}" if tt
    w = @brand['display_weight'].to_i
    out << "body.bf .name,body.bf .plate,body.bf .pl,body.bf .brand,body.bf main h2:not(.rule-h):not(.bh),body.bf .hl,body.bf .where{font-weight:#{w}}" if w.between?(100, 900)
    out.join
  end
  def kparts; s['kicker'].to_s.split(' · ').map(&:strip).reject { |x| x =~ /\Asample site\z/i } end
  def extra; kparts[2] end
  def trade; kparts.first.to_s end
  def area; kparts[1] || city end
  def aparts; s['address'].to_s.split(',').map(&:strip).reject(&:empty?) end
  def street; aparts.first.to_s end
  def city; (aparts[1] || '').sub(/\s+(ON|QC|BC|AB|MB|SK|NS|NB|NL|PE)\b.*/, '') end
  def addr?; !blank?(s['address']) end
  def tel?; !blank?(s['tel']) end
  def email?; !blank?(s['email']) end
  def rating?; !blank?(s['rating']) end
  def proof; (sample? || blank?(s['proof']) || s['proof'] =~ /\Asample site\z/i) ? nil : s['proof'] end
  def book; blank?(s['book_url']) ? nil : s['book_url'] end
  def book_label; s['book_label'] || 'Book online' end
  def maps; 'https://www.google.com/maps/search/?api=1&query=' + ERB::Util.url_encode("#{s['name']} #{s['address']}") end
  def dir; 'https://www.google.com/maps/dir/?api=1&destination=' + ERB::Util.url_encode("#{s['name']} #{s['address']}") end
  def embed; 'https://maps.google.com/maps?q=' + ERB::Util.url_encode(sample? ? 'Ottawa, ON' : "#{s['name']}, #{s['address']}") + '&z=15&output=embed' end
  def email_mode?; (s['cta'] == 'email' && email?) || !tel? end
  def primary_href; email_mode? ? "mailto:#{s['email']}" : "tel:#{s['tel']}" end
  def contact?; tel? || email? end
  def alt; final? ? s['name'] : (sample? ? 'Sample photo' : "Placeholder photo for #{s['name']}") end
  def photo_label; final? ? nil : (sample? ? 'Sample photo' : 'Placeholder photo') end
  def photos
    @photos ||= begin
      ids = Array(s['photos']).map(&:to_s).uniq
      unless final?
        ids -= PHOTO_NEVER
        ids -= PHOTO_INTERIOR unless sample?
        ids -= PHOTO_HAIR_ONLY unless HAIR_TRADE.(trade)
      end
      ids
    end
  end
  def np; photos.size end
  def ph?(i) i < np end
  def menu; Array(s['menu']) end
  def founding; FOUNDING > 0 end  # Canada-wide since 2026-11-26 (owner: advertise the first-3 offer outright)
  def tz; TZ[s['address'].to_s[/\b(ON|QC|BC|AB|MB|SK|NS|NB|NL|PE)\b/]] || 'America/Toronto' end
  def week; @week end
  def week_json; JSON.generate(@week.map { |d| d.is_a?(Array) ? d : (d == :closed ? 0 : nil) }) end

  # The main action first (book link if there is one, otherwise call/email), then the rest. Never more than three.
  def actions
    out = []
    out << { k: 'book', label: book_label, href: book, ext: true } if book
    if contact?
      if email_mode?
        out << { k: 'mail', label: (book ? 'Email' : s['cta_label']), href: "mailto:#{s['email']}" }
      else
        out << { k: 'phone', label: (book ? "Call #{s['phone']}" : s['cta_label']), href: "tel:#{s['tel']}" }
      end
    end
    out << { k: 'pin', label: 'Directions', href: dir, ext: true } if addr?
    out
  end
  def action_btns(icons: false, max: 3)
    actions.first(max).each_with_index.map { |x, i|
      %(<a class="act #{i == 0 ? 'act-p' : 'act-q'}" href="#{e x[:href]}"#{x[:ext] ? ' target="_blank" rel="noopener"' : ''}>#{icons || i > 0 ? icon(x[:k] == 'book' && x[:label] =~ /order/i ? 'bag' : x[:k], 17) : ''}<span>#{x[:k] == 'phone' && x[:label].to_s.start_with?('Call ') && tel? && x[:label].to_s.end_with?(s['phone'].to_s) ? %(Call <span class="num">#{e s['phone']}</span>) : tx(x[:label])}</span></a>)
    }.join
  end
  def primary_link(cls = 'tl')
    x = actions.first or return ''
    %(<a class="#{cls}" href="#{e x[:href]}"#{x[:ext] ? ' target="_blank" rel="noopener"' : ''}>#{tx x[:label]}</a>)
  end
  # live "Open now · closes 7 pm" (filled by the small script; nothing when hours are not machine-readable)
  def now(cls = '') week ? %(<span class="now #{cls}" data-now hidden></span>) : '' end
  # hours that are a sentence ("Call for today's hours", "By appointment"), not a timetable: shown as one line, never as a table
  def hours_note?
    return false if week || blank?(s['hours'])
    segs = s['hours'].split(/\s*·\s*/)
    !(segs.all? { |x| x =~ /\A(mon|tue|wed|thu|fri|sat|sun|closed|emergenc|weekday|weekend|daily)/i } && segs.any? { |x| x =~ /\d/ })
  end
  def hours_table?; !blank?(s['hours']) && !hours_note? end
  def hours_note_html
    hx = tx(s['hours'])
    hx =~ /google/i && addr? ? %(<a class="hn" href="#{maps}" target="_blank" rel="noopener">#{hx}</a>) : %(<span class="hn">#{hx}</span>)
  end
  def hours_html
    return '' if hours_note?
    if week
      rows = week.each_with_index.map { |d, i|
        next '' if d.nil?   # a day the listing does not mention is left out, not guessed
        v = d.is_a?(Array) ? "#{fmt_t(d[0])} – #{fmt_t(d[1])}" : 'Closed'
        %(<tr data-d="#{i}"><th scope="row">#{DAY_FULL[i]}</th><td>#{v}</td></tr>)
      }.join
      %(<table class="hrs"><caption class="vh">Opening hours</caption>#{rows}</table>)
    elsif !blank?(s['hours'])
      %(<ul class="hrs-l">#{s['hours'].split(/\s*·\s*/).map { |x| "<li>#{tx x}</li>" }.join}</ul>)
    else
      ''
    end
  end
  def rating_line(cls = '')
    if rating?
      %(<a class="rate #{cls}" href="#{maps}" target="_blank" rel="noopener"><span class="stars" aria-hidden="true">#{stars(s['rating'])}</span><span><b>#{e s['rating']}</b> from #{e s['reviews']} Google reviews</span></a>)
    elsif proof
      %(<span class="rate rate-t #{cls}">#{tx proof}</span>)
    else
      ''
    end
  end
  def copy_addr
    addr? ? %(<button type="button" class="copy" data-copy="#{e s['address']}">Copy address</button>) : ''
  end
  def addr_html
    return '' unless addr?
    rest = aparts[1..-1].join(', ')
    return %(<a class="addr" href="#{maps}" target="_blank" rel="noopener"><span>#{tx s['address']}</span></a>) unless street =~ /\d/   # no street number: keep it on one line
    %(<a class="addr" href="#{maps}" target="_blank" rel="noopener"><span>#{tx street}</span>#{rest.empty? ? '' : " <span>#{tx rest}</span>"}</a>)
  end
  # photo figure with the honest label
  def ph(i, w, cls: '', sizes: '100vw', lazy: true, label: true, n: nil)
    return '' unless ph?(i)
    id = photos[i].to_s
    ss = srcset(id, [480, 800, 1200, 1800].select { |x| x <= [w * 1.5, 1800].min })
    cap = [n, (label ? photo_label : nil)].compact.join(' · ')
    %(<figure class="ph #{cls}"><img src="#{img(id, w)}"#{ss ? %( srcset="#{ss}" sizes="#{sizes}") : ''} alt="#{e alt}"#{lazy ? ' loading="lazy"' : ' fetchpriority="high"'} decoding="async">#{cap.empty? ? '' : "<figcaption>#{e cap}</figcaption>"}</figure>)
  end
  def yours(cls = '')
    draft? ? %(<figure class="ph yours #{cls}"><div><i aria-hidden="true"></i><b>Your photos here</b><span>Text them to us. Free.</span></div></figure>) : ''
  end
  def photo_note
    final? ? s['photo_credit'].to_s : (sample? ? 'Photos via Unsplash.' : 'Placeholder photos via Unsplash. Your own photos go here.')
  end
  # one quiet colophon line at the end of the page instead of notes scattered under every section
  def colophon
    if final? then s['photo_credit'].to_s
    elsif sample? then np > 0 ? 'Photos via Unsplash.' : ''
    else "Draft notes: service list to confirm with the owner. " + (np > 0 ? 'Placeholder photos via Unsplash; your own photos go here.' : 'No photos yet; your own photos go here.')
    end
  end
  def menu_cta
    return %q() unless book
    lbl = food? ? %q(See the full menu & prices) : %q(See all services & prices)
    %(<p class="menu-cta"><a href="#{e book}"#{book.start_with?('#') ? '' : ' target="_blank" rel="noopener"'}><span>#{lbl}</span><i aria-hidden="true">#{icon('arrow', 20)}</i></a></p>)
  end
  def svc_note; asides_html + menu_cta end
  def all_services; Array(s['services']).reject { |t, *_| t.to_s.strip =~ SVC_ACTION } end
  def services; all_services.reject { |t, *_| t.to_s.strip =~ SVC_ASIDE } end
  def asides; all_services.select { |t, *_| t.to_s.strip =~ SVC_ASIDE } end
  def asides_html
    return '' if asides.empty?
    items = asides.map { |t, d, _| tt = t.to_s.strip; %(<li><b>#{tx tt}#{tt =~ /[.?!]\z/ ? '' : '.'}</b> #{tx d}</li>) }.join
    %(<div class="gtk"><h3>Good to know</h3><ul>#{items}</ul></div>)
  end
  # the About heading: 130 of 149 drafts had a rating formula here ("4.8 stars from 120 customers."), on top of the
  # rating in the hero and again in the paragraph. Say the number once; give the section a plain human heading.
  def about_h
    h = s['about_h'].to_s
    return h unless h =~ RATING_H
    if s['about'].to_s =~ /review|mention|describe|customers say|clients say/i
      ['Word gets around.', 'What the reviews say.'][seed(s, 'ah') % 2]
    else
      "About #{name}"
    end
  end
  # the sub line without a second copy of the rating (the hero already shows it once, with the stars)
  def sub_line
    t = s['sub'].to_s
    return t unless rating?
    t = t.gsub(/,?\s+rated (a perfect )?\d\.\d on Google( by [\d,]+ \w+)?(,(?= and ))?(?=[.,]| and )/, '')
    t = t.gsub(/(?<=[.!?])\s+Rated (a perfect )?\d\.\d on Google( by [\d,]+ \w+)?\.(?=\s|\z)/, '')
    t = t.sub(/\ARated (a perfect )?\d\.\d on Google( by [\d,]+ \w+)?\.\s+/, '')
    t = t.strip
    t.empty? ? s['sub'].to_s : t
  end
  # optional price list: "menu": [{"title":..,"items":[[name, detail, price],..]}]
  def menu_html
    return '' if menu.empty?
    groups = menu.map { |g|
      rows = Array(g['items']).map { |n, d, p| %(<li><span class="mn">#{tx n}#{blank?(d) ? '' : "<small>#{tx d}</small>"}</span><span class="ml" aria-hidden="true"></span><span class="mp">#{tx p}</span></li>) }.join
      %(<div class="mg"><h3>#{tx g['title']}</h3><ul>#{rows}</ul></div>)
    }.join
    note = blank?(s['menu_note']) ? (sample? ? 'Sample prices.' : (draft? ? 'Prices to confirm with the owner.' : '')) : s['menu_note']
    %(<div class="menu">#{groups}</div>#{note.empty? ? '' : %(<p class="note">#{tx note}</p>)})
  end
  def areas_html
    a = Array(s['areas']); return '' if a.empty?
    %(<ul class="areas">#{a.map { |x| "<li>#{tx x}</li>" }.join}</ul>)
  end
  def map_html
    addr? ? %(<div class="map"><a class="map-ph" href="#{maps}" target="_blank" rel="noopener">#{icon('pin', 22)}<b>#{tx(street =~ /\d/ ? street : s['address'])}</b><span>Open in Google Maps</span></a><iframe src="#{embed}" title="Map" loading="lazy" referrerpolicy="no-referrer-when-downgrade"></iframe></div>) : ''
  end
  # contact rows used in every "visit" block: [label, html]
  def contact_rows
    r = []
    r << ['Address', addr_html + %(<span class="sub"><a class="tl" href="#{dir}" target="_blank" rel="noopener">Directions</a>#{copy_addr}</span>)] if addr?
    r << ['Phone', %(<a class="big" href="tel:#{e s['tel']}">#{e s['phone']}</a>)] if tel?
    r << ['Email', %(<a class="big em" href="mailto:#{e s['email']}">#{e s['email'].to_s.downcase}</a>)] if email?
    r << ['Hours', hours_note_html] if hours_note?
    r << ['Instagram', %(<a class="big" href="https://www.instagram.com/#{e s['instagram']}/" target="_blank" rel="noopener">@#{e s['instagram']}</a>)] unless blank?(s['instagram'])
    r
  end
  def contact_dl
    %(<dl class="cdl">#{contact_rows.map { |l, h| "<div><dt>#{l}</dt><dd>#{h}</dd></div>" }.join}</dl>)
  end
  def about_link
    if rating? then %(<a class="tl" href="#{maps}" target="_blank" rel="noopener">Read the reviews on Google</a>)
    elsif !blank?(s['instagram']) then %(<a class="tl" href="https://www.instagram.com/#{e s['instagram']}/" target="_blank" rel="noopener">See what's fresh on Instagram</a>)
    else primary_link end
  end
  def lede; s['h1'].to_s end
  def food?; trade =~ FOOD_RE end
  def svc_title
    return 'In store' if trade =~ /grocery|butcher|market|variety|thrift|clothing|jewell/i
    menu.empty? && food? ? 'On the menu' : (food? ? 'What we serve' : 'Services')
  end
  def area_line; [trade, area, extra].reject { |x| blank?(x) } end
  def today_line; week ? now : (blank?(s['hours']) ? '' : %(<span class="hrs-s">#{e s['hours']}</span>)) end
  # body classes the layouts style against: how many photos, whether there is a timetable
  def flags; "np#{np}#{hours_table? ? '' : ' no-hrs'}#{draft? ? ' is-draft' : ''}#{services.size.odd? ? ' svc-odd' : ''}#{brand? ? ' bf' : ''}#{brand_fonts? || !@kase.empty? ? ' bfit' : ''}" end
  def name_n; [name.split(/\s+/).map(&:size).max, (name.size / 2.0).ceil].max end
  def font_url
    font_urls.first
  end
  # The layout's own fonts in one request; each brand font in its own, so a mistyped brand font can only lose itself.
  def font_urls
    g = ->(fams) { "https://fonts.googleapis.com/css2?#{fams.map { |f| 'family=' + f.gsub(' ', '+') }.join('&')}&display=swap" }
    keep = @a['fonts'].each_with_index.reject { |_, i| i < 2 && @bfonts[i] }.map(&:first)
    (keep.empty? ? [] : [g.(keep)]) + @bfonts.compact.map { |_, spec| spec }.uniq.map { |spec| g.([spec]) }
  end
  def css_vars
    p = pal
    "--bg:#{p['bg']};--paper:#{p['paper']};--ink:#{p['ink']};--muted:#{p['muted']};--accent:#{p['accent']};--at:#{p['at']};--on:#{p['on']};--line:#{p['line']};--n:#{name_n}"
  end
  def get_binding; binding end
end

if $0 == __FILE__
SHELL = ERB.new(File.read(File.join(ROOT, 'template.html.erb'), encoding: 'UTF-8'), trim_mode: '-')
BASE_CSS = File.read(File.join(ROOT, 'base.css'), encoding: 'UTF-8')
LAY = Hash.new { |h, k| h[k] = [ERB.new(File.read(File.join(ROOT, 'layouts', "#{k}.html.erb"), encoding: 'UTF-8'), trim_mode: '-'), File.read(File.join(ROOT, 'layouts', "#{k}.css"), encoding: 'UTF-8')] }
def minify(css) css.gsub(%r{/\*.*?\*/}m, '').gsub(/\s*\n\s*/, '').gsub(/\s*([{};,>])\s*/, '\1') end

only = ENV['ONLY'].to_s.split(',')
index = []
SITES.each do |s|
  next unless only.empty? || only.include?(s['slug'])
  c = Ctx.new(s)
  tpl, css = LAY[c.art]
  t = c.pal; book = c.book; founding = c.founding
  body_html = tpl.result(c.get_binding)
  page_css = minify(BASE_CSS + css)
  out = File.join(ROOT, 'out', s['dir'], s['slug']); FileUtils.mkdir_p(out)
  File.write(File.join(out, 'index.html'), SHELL.result(binding))
  index << [s['dir'], s['slug'], s['name'], c.art, c.pal_name, c.v]
  puts "built #{s['dir']}/#{s['slug']}  [#{c.art}/#{c.pal_name}/v#{c.v}]"
end
unless BRAND_WARN.empty?
  warn "#{BRAND_WARN.size} brand warning(s): the pages above were built with the safe fallbacks."
end
# local review index (never published)
if only.empty?
  rows = index.map { |d, sl, n, a, p, v| %(<tr><td><a href="#{d}/#{sl}/">#{e n}</a></td><td>#{d}</td><td>#{a}</td><td>#{p}</td><td>v#{v}</td></tr>) }.join
  File.write(File.join(ROOT, 'out', 'index.html'), %(<!doctype html><meta charset="utf-8"><meta name="robots" content="noindex"><title>v4 review index</title><style>body{font:15px/1.5 system-ui;margin:40px}td,th{padding:6px 14px;border-bottom:1px solid #ddd;text-align:left}</style><h1>v4 review index (local only)</h1><table><tr><th>Site</th><th>Dir</th><th>Art direction</th><th>Palette</th><th>Variant</th></tr>#{rows}</table>))
end
end
