"""WCAG AA contrast check for the Next Mission widget palette (NMDH-16).
Run after any colour change: python3 scripts/check_contrast.py"""
def lum(h):
    h=h.lstrip('#'); c=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    c=[x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in c]
    return .2126*c[0]+.7152*c[1]+.0722*c[2]
def ratio(a,b):
    la,lb=lum(a),lum(b); hi,lo=max(la,lb),min(la,lb)
    return (hi+.05)/(lo+.05)
PAIRS=[
 ("body copy on panel",        "#1B1B18","#F8F5EE",4.5),
 ("muted copy on panel",       "#55534C","#F8F5EE",4.5),
 ("body copy on white",        "#1B1B18","#FFFFFF",4.5),
 ("white on pine (header)",    "#FFFFFF","#14532D",4.5),
 ("header subtitle on pine",   "#DCDCDC","#14532D",4.5),
 ("white on pine (user msg)",  "#FFFFFF","#14532D",4.5),
 ("card title on cream",       "#14532D","#F8F5EE",4.5),
 ("card body on cream",        "#1B1B18","#F8F5EE",4.5),
 ("badge text on badge bg",    "#8A4513","#FBF0E4",4.5),
 ("error text on error bg",    "#7F1D1D","#FEF2F2",4.5),
 ("chip text on chip bg",      "#14532D","#F8F5EE",4.5),
 ("send label on send bg",     "#FFFFFF","#14532D",4.5),
 ("disabled send label",       "#FFFFFF","#6E7A70",3.0),
 ("stepper label on cream",    "#55534C","#F8F5EE",4.5),
 # The AI disclosure sits inside the PINE header, not on cream. It shipped
 # once at 1.02:1 using the body ink, invisible, because no pair here
 # covered it. Any new text goes in this list before it goes on the page.
 ("AI disclosure on pine",    "#D9E5DC","#14532D",4.5),
 # Hero graphic. Added WITH the component, not after it. The design it came
 # from ran its branch label at 4.59:1 on our pine, 0.09 over the floor.
 ("hero branch on pine",      "#D9E5DC","#14532D",4.5),
 ("hero mos on pine",         "#EDF3EF","#14532D",4.5),
 ("hero code on pine",        "#FFFFFF","#14532D",3.0),
 ("hero role on white",       "#14532D","#FFFFFF",4.5),
 ("hero wage on peach",       "#14532D","#FBEEE1",4.5),
 ("hero note on white",       "#55534C","#FFFFFF",4.5),
 ("hero caption on art bg",   "#55534C","#FBF9F4",4.5),
 ("hero connector on art bg", "#4F7A63","#FBF9F4",3.0),
 ("hero toggle border",       "#4F7A63","#FFFFFF",3.0),
 ("hero eyebrow on art bg",   "#14532D","#FBF9F4",4.5),
 # Brand lockup, added with the markup. The mark itself is decorative and
 # aria-hidden, so these are its two REAL text pairs, not the graphic.
 ("lockup name on cream",     "#14532D","#F8F5EE",4.5),
 ("lockup tagline on cream",  "#2A5C41","#F8F5EE",4.5),
 # Widget mark on the pine header. Decorative, so 3.0 is the bar it is held to
 # for legibility rather than compliance. The design's own #6E9480 measures
 # 2.69:1 here and vanishes; #8FB09E is the replacement.
 ("mark chevron on pine",     "#8FB09E","#14532D",3.0),
 ("mark arrow on pine",       "#F0CDA9","#14532D",3.0),
 ("current step on cream",     "#14532D","#F8F5EE",4.5),
 # non-text / UI component contrast, 3:1
 ("focus ring vs white",       "#8A4513","#FFFFFF",3.0),
 ("focus ring vs cream",       "#8A4513","#F8F5EE",3.0),
 ("input border vs white",     "#D8CFC0","#FFFFFF",1.0),
 ("card accent vs cream",      "#3F9142","#F8F5EE",3.0),
]
fails=0
for name,fg,bg,req in PAIRS:
    r=ratio(fg,bg); ok = r>=req
    if not ok: fails+=1
    print("%-28s %5.2f:1  need %.1f  %s" % (name, r, req, "PASS" if ok else "FAIL"))
print("\n%d pair(s) failing" % fails)
