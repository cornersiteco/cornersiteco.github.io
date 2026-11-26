# encoding: utf-8
# Corner Site Co. draft generator, v4 ("art directions").
#   ruby build.rb                      -> out/<dir>/<slug>/index.html for every entry in sites.json
#   ONLY=slug-a,slug-b ruby build.rb   -> only those slugs
# Rules (unchanged): only verified facts for real businesses; photos are Unsplash (free licence)
# placeholders, labelled; real drafts carry the draft banner + noindex.
# Files: template.html.erb (shell), base.css, layouts/<art>.html.erb + layouts/<art>.css, themes.json (arts + palettes).
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
  'book'=>'<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/>'
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

# ---------- art direction choice ----------
# 1) sites.json "art" (or "layout" if it already holds a v4 name); 2) niche words in the kicker; 3) the old theme.
NICHE_ART = [
  [/nail|lash|brow|tattoo|piercing|detailing|makeup|jewell/i, 'gallery'],
  [/barber/i, 'poster'],
  [/caf[eé]|coffee|bakery|bake|patisserie|grocery|butcher|deli|ice cream|donut|tea\b/i, 'menu'],
  [/restaurant|kitchen|pub\b|bar\b|grill|pizza|taco|cuisine|diner|bistro|eatery|sushi|shawarma|food/i, 'gazette'],
  [/auto|mechanic|tire|electric|plumb|hvac|roof|contract|garage|repair|landscap|pawn|gold buying/i, 'spec'],
  [/hair|salon|spa|beauty|wax|esthet|skin|groom|clinic|law|tailor|veterin|wellness|thrift/i, 'atelier']
]
THEME_ART = {'auto'=>'spec','detailing'=>'gallery','electric'=>'spec','barber'=>'poster','tattoo'=>'gallery','salon'=>'atelier','clinic'=>'atelier','law'=>'atelier','gold'=>'atelier','thrift'=>'atelier','tacos'=>'gazette','ethiopian'=>'gazette','italian'=>'gazette','pub'=>'gazette','bakery'=>'menu','cafe'=>'menu','grocery'=>'menu'}
def art_for(s)
  return s['art'] if ARTS.key?(s['art'])
  return s['layout'] if ARTS.key?(s['layout'])
  k = s['kicker'].to_s.split(' · ').first.to_s
  NICHE_ART.each { |re, a| return a if k =~ re }
  THEME_ART[s['theme']] || 'atelier'
end
def seed(s, salt = '') Zlib.crc32(s['slug'].to_s + salt) end

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
def poster_html(name, maxw, cls)
  poster_lines(name, maxw).map { |l| %(<span class="pl #{cls}" style="--w:#{anton_w(l).round(3)}">#{e l.upcase}</span>) }.join
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
    @pal = @a['palettes'].fetch(@pal_name)
    @v = (s['variant'] || seed(s, 'v')).to_i % 3
    @week = hours_parse(s['hours'])
  end
  def final?; !!s['final'] end
  def sample?; !!s['sample'] end
  def draft?; !final? && !sample? end
  def name; s['name'] end
  def kparts; s['kicker'].to_s.split(' · ').map(&:strip).reject { |x| x =~ /\Asample site\z/i } end
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
  def photos; Array(s['photos']) end
  def menu; Array(s['menu']) end
  def founding; FOUNDING > 0 && !!(s['address'].to_s =~ OTTAWA_RE) end
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
      %(<a class="act #{i == 0 ? 'act-p' : 'act-q'}" href="#{e x[:href]}"#{x[:ext] ? ' target="_blank" rel="noopener"' : ''}>#{icons ? icon(x[:k]) : ''}<span>#{e x[:label]}</span></a>)
    }.join
  end
  def primary_link(cls = 'tl')
    x = actions.first or return ''
    %(<a class="#{cls}" href="#{e x[:href]}"#{x[:ext] ? ' target="_blank" rel="noopener"' : ''}>#{e x[:label]}</a>)
  end
  # live "Open now · closes 7 pm" (filled by the small script; nothing when hours are not machine-readable)
  def now(cls = '') week ? %(<span class="now #{cls}" data-now hidden></span>) : '' end
  def hours_html
    if week
      rows = week.each_with_index.map { |d, i|
        v = d.is_a?(Array) ? "#{fmt_t(d[0])} – #{fmt_t(d[1])}" : (d == :closed ? 'Closed' : '—')
        %(<tr data-d="#{i}"><th scope="row">#{DAY_FULL[i]}</th><td>#{v}</td></tr>)
      }.join
      %(<table class="hrs"><caption class="vh">Opening hours</caption>#{rows}</table>)
    elsif !blank?(s['hours'])
      %(<ul class="hrs-l">#{s['hours'].split(/\s*·\s*/).map { |x| "<li>#{e x}</li>" }.join}</ul>)
    else
      ''
    end
  end
  def rating_line(cls = '')
    if rating?
      %(<a class="rate #{cls}" href="#{maps}" target="_blank" rel="noopener"><span class="stars" aria-hidden="true">#{stars(s['rating'])}</span><span><b>#{e s['rating']}</b> from #{e s['reviews']} Google reviews</span></a>)
    elsif proof
      %(<span class="rate rate-t #{cls}">#{e proof}</span>)
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
    %(<a class="addr" href="#{maps}" target="_blank" rel="noopener"><span>#{e street}</span>#{rest.empty? ? '' : " <span>#{e rest}</span>"}</a>)
  end
  # photo figure with the honest label
  def ph(i, w, cls: '', sizes: '100vw', lazy: true, label: true, n: nil)
    id = photos[i % [photos.size, 1].max].to_s
    ss = srcset(id, [480, 800, 1200, 1800].select { |x| x <= [w * 1.5, 1800].min })
    cap = [n, (label ? photo_label : nil)].compact.join(' · ')
    %(<figure class="ph #{cls}"><img src="#{img(id, w)}"#{ss ? %( srcset="#{ss}" sizes="#{sizes}") : ''} alt="#{e alt}"#{lazy ? ' loading="lazy"' : ' fetchpriority="high"'} decoding="async">#{cap.empty? ? '' : "<figcaption>#{e cap}</figcaption>"}</figure>)
  end
  def yours(cls = '')
    draft? ? %(<figure class="ph yours #{cls}"><div><b>Your photos here</b><span>Text them to us. Free.</span></div></figure>) : ''
  end
  def photo_note
    final? ? s['photo_credit'].to_s : (sample? ? 'Photos via Unsplash.' : 'Placeholder photos via Unsplash. Your own photos go here.')
  end
  def svc_note; draft? ? '<p class="note">Service list to confirm with the owner.</p>' : '' end
  def services; Array(s['services']) end
  # optional price list: "menu": [{"title":..,"items":[[name, detail, price],..]}]
  def menu_html
    return '' if menu.empty?
    groups = menu.map { |g|
      rows = Array(g['items']).map { |n, d, p| %(<li><span class="mn">#{e n}#{blank?(d) ? '' : "<small>#{e d}</small>"}</span><span class="ml" aria-hidden="true"></span><span class="mp">#{e p}</span></li>) }.join
      %(<div class="mg"><h3>#{e g['title']}</h3><ul>#{rows}</ul></div>)
    }.join
    note = blank?(s['menu_note']) ? (sample? ? 'Sample prices.' : (draft? ? 'Prices to confirm with the owner.' : '')) : s['menu_note']
    %(<div class="menu">#{groups}</div>#{note.empty? ? '' : %(<p class="note">#{e note}</p>)})
  end
  def areas_html
    a = Array(s['areas']); return '' if a.empty?
    %(<ul class="areas">#{a.map { |x| "<li>#{e x}</li>" }.join}</ul>)
  end
  def map_html
    addr? ? %(<div class="map"><iframe src="#{embed}" title="Map" loading="lazy" referrerpolicy="no-referrer-when-downgrade"></iframe></div>) : ''
  end
  # contact rows used in every "visit" block: [label, html]
  def contact_rows
    r = []
    r << ['Address', addr_html + %(<span class="sub"><a class="tl" href="#{dir}" target="_blank" rel="noopener">Directions</a>#{copy_addr}</span>)] if addr?
    r << ['Phone', %(<a class="big" href="tel:#{e s['tel']}">#{e s['phone']}</a>)] if tel?
    r << ['Email', %(<a class="big em" href="mailto:#{e s['email']}">#{e s['email']}</a>)] if email?
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
  def food?; trade =~ /restaurant|kitchen|pub|bar\b|grill|pizza|taco|cuisine|diner|bistro|caf|coffee|bakery|food|grocery|butcher/i end
  def svc_title; menu.empty? && food? ? 'On the menu' : (food? ? 'What we serve' : 'Services') end
  def area_line; [trade, area].reject { |x| blank?(x) } end
  def today_line; week ? now : (blank?(s['hours']) ? '' : %(<span class="hrs-s">#{e s['hours']}</span>)) end
  def name_n; [name.split(/\s+/).map(&:size).max, (name.size / 2.0).ceil].max end
  def font_url
    "https://fonts.googleapis.com/css2?#{@a['fonts'].map { |f| 'family=' + f.gsub(' ', '+') }.join('&')}&display=swap"
  end
  def css_vars
    p = pal
    "--bg:#{p['bg']};--paper:#{p['paper']};--ink:#{p['ink']};--muted:#{p['muted']};--accent:#{p['accent']};--on:#{p['on']};--line:#{p['line']};--n:#{name_n}"
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
# local review index (never published)
if only.empty?
  rows = index.map { |d, sl, n, a, p, v| %(<tr><td><a href="#{d}/#{sl}/">#{e n}</a></td><td>#{d}</td><td>#{a}</td><td>#{p}</td><td>v#{v}</td></tr>) }.join
  File.write(File.join(ROOT, 'out', 'index.html'), %(<!doctype html><meta charset="utf-8"><meta name="robots" content="noindex"><title>v4 review index</title><style>body{font:15px/1.5 system-ui;margin:40px}td,th{padding:6px 14px;border-bottom:1px solid #ddd;text-align:left}</style><h1>v4 review index (local only)</h1><table><tr><th>Site</th><th>Dir</th><th>Art direction</th><th>Palette</th><th>Variant</th></tr>#{rows}</table>))
end
end
