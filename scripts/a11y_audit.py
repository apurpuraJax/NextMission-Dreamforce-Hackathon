"""Static accessibility audit of the LWC markup. Catches the classes of defect
that are visible in the source, so they do not have to be found by a human with
a screen reader. Run: python3 scripts/a11y_audit.py"""
import re, sys, os, glob

FINDINGS = []
def flag(sev, comp, msg):  FINDINGS.append((sev, comp, msg))

INTERACTIVE = re.compile(r'<(button|input|textarea|select|a)\b', re.I)

for html in sorted(glob.glob('force-app/main/default/lwc/*/*.html')):
    comp = os.path.basename(os.path.dirname(html))
    src  = open(html).read()
    css_path = html.replace('.html', '.css')
    css  = open(css_path).read() if os.path.exists(css_path) else ''

    # 1. aria-busy on a live region suppresses announcements
    for m in re.finditer(r'<[^>]*aria-live[^>]*>', src, re.S):
        if 'aria-busy' in m.group(0):
            flag('HIGH', comp, 'aria-busy on a live region suppresses screen-reader announcements')

    # 2. competing accessible names: a labelled control that also has aria-label
    for m in re.finditer(r'<input\b[^>]*>', src, re.S):
        tag = m.group(0)
        idm = re.search(r'id="([^"]+)"', tag)
        if idm and re.search(r'<label[^>]*for="%s"' % re.escape(idm.group(1)), src) and 'aria-label' in tag:
            flag('MED', comp, 'input #%s has BOTH a <label for> and aria-label; aria-label silently wins' % idm.group(1))

    # 3. placeholder used as the only name
    for m in re.finditer(r'<input\b[^>]*>', src, re.S):
        tag = m.group(0)
        idm = re.search(r'id="([^"]+)"', tag)
        labelled = ('aria-label' in tag) or (idm and re.search(r'<label[^>]*for="%s"' % re.escape(idm.group(1)), src))
        if 'placeholder' in tag and not labelled:
            flag('HIGH', comp, 'input relies on placeholder alone for its name')

    # 4. interactive element with no focus style anywhere in the CSS
    for m in INTERACTIVE.finditer(src):
        pass
    classes = set(re.findall(r'class="(nm-[a-z-]+)"', src))
    for m in re.finditer(r'<(button|input)\b[^>]*class="(nm-[a-z-]+)"', src, re.S):
        cls = m.group(2)
        if (':focus' not in css) or (cls not in css):
            continue
        block = re.search(r'\.%s:focus(-visible)?\s*\{' % re.escape(cls), css)
        if not block:
            flag('HIGH', comp, '.%s is interactive but has no :focus-visible style' % cls)

    # 5. outline removed without replacement
    for m in re.finditer(r'([.#][\w-]+[^{]*)\{[^}]*outline:\s*(none|0)[^}]*\}', css, re.S):
        sel = m.group(1).strip()
        if 'focus' not in sel and not re.search(r'%s:focus' % re.escape(sel.split()[0]), css):
            flag('HIGH', comp, 'outline removed on %s with no :focus replacement' % sel)

    # 6. svg without aria-hidden or a role/label
    for m in re.finditer(r'<svg\b[^>]*>', src, re.S):
        tag = m.group(0)
        if 'aria-hidden' in tag or 'role="img"' in tag:
            continue
        # An svg inside an aria-hidden ancestor is already hidden. Look back for
        # the nearest unclosed opening tag and honour it, otherwise every
        # correctly-hidden decorative icon is reported as a defect.
        before = src[:m.start()]
        opens = re.findall(r'<(span|div|button|p)\b[^>]*>|</(span|div|button|p)>', before)
        depth, hidden = 0, False
        for om in reversed(list(re.finditer(r'<(span|div|button|p)\b([^>]*)>|</(span|div|button|p)>', before))):
            if om.group(3):
                depth += 1
            else:
                if depth == 0:
                    hidden = 'aria-hidden="true"' in (om.group(2) or '')
                    break
                depth -= 1
        if not hidden:
            flag('MED', comp, 'svg is neither aria-hidden nor role="img" with a label')

    # 7. heading order
    hs = [int(h) for h in re.findall(r'<h([1-6])', src)]
    for a, b in zip(hs, hs[1:]):
        if b > a + 1:
            flag('MED', comp, 'heading level jumps from h%d to h%d' % (a, b))

    # 8. positive tabindex breaks natural order
    if re.search(r'tabindex="[1-9]', src):
        flag('HIGH', comp, 'positive tabindex overrides natural focus order')

    # 9. duplicate ids
    ids = re.findall(r'\bid="([^"]+)"', src)
    for i in set(ids):
        if ids.count(i) > 1:
            flag('MED', comp, 'duplicate id "%s"' % i)

    # 10. button without an explicit type inside a form context
    for m in re.finditer(r'<button\b(?![^>]*type=)[^>]*>', src, re.S):
        flag('LOW', comp, 'button without an explicit type attribute')

    # 11. animation without a reduced-motion escape
    if re.search(r'animation:', css) and 'prefers-reduced-motion' not in css:
        flag('MED', comp, 'CSS animates but has no prefers-reduced-motion block')

    # 12. touch targets
    for m in re.finditer(r'\.(nm-[a-z-]+)\s*\{([^}]*)\}', css, re.S):
        cls, body = m.group(1), m.group(2)
        if re.search(r'<button[^>]*class="%s"' % re.escape(cls), src):
            mh = re.search(r'min-height:\s*([\d.]+)rem', body)
            if mh and float(mh.group(1)) * 16 < 44:
                flag('LOW', comp, '.%s min-height %.0fpx is under the 44px target' % (cls, float(mh.group(1))*16))

    # 13. sr-only class used but never defined
    if 'nm-sr-only' in src and '.nm-sr-only' not in css:
        flag('HIGH', comp, 'uses .nm-sr-only but does not define it')
    if 'slds-assistive-text' in src:
        flag('MED', comp, 'depends on slds-assistive-text, a class this component does not own')

    # 14. live region that is not always present in the DOM
    for m in re.finditer(r'<template lwc:if=[^>]*>\s*<[^>]*aria-live', src, re.S):
        flag('MED', comp, 'a live region inside lwc:if may not exist when content arrives')

sev_order = {'HIGH':0,'MED':1,'LOW':2}
FINDINGS.sort(key=lambda f: (sev_order[f[0]], f[1]))
print("=" * 70)
print("%d finding(s)" % len(FINDINGS))
print("=" * 70)
for s, c, m in FINDINGS:
    print("  %-5s %-14s %s" % (s, c, m))
if not FINDINGS:
    print("  none")
sys.exit(1 if any(f[0]=='HIGH' for f in FINDINGS) else 0)
