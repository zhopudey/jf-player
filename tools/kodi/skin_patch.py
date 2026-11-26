#!/usr/bin/env python3
"""All jf-player edits to Aeon Nox SiLVO 10.0.3, applied to pristine copies (UI_SPEC.md).

  ./skin_patch.py ORIG_DIR OUT_DIR
ORIG_DIR holds the untouched skin files (16x9/*.xml); OUT_DIR gets the patched ones.
Shared pieces are defined ONCE in Includes.xml (JF* includes) and used everywhere:
  JFRatingBadge  - rating badge, bottom-right of a 200x300 poster (walls + Home rows)
  JFMediaFlags   - flag row: resolution, HDR, video codec, audio codec, channels
"""
import os, re, sys
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
def load(f): return open(os.path.join(src, f)).read()
def save(f, s): open(os.path.join(out, f), "w").write(s)
def once(s, old, new, count=1):
    assert s.count(old) >= count, f"anchor not found: {old[:60]!r}"
    return s.replace(old, new, count)

def flag(tex, vis):
    return (f'\t\t\t<control type="image">\n\t\t\t\t<width>120</width>\n\t\t\t\t<height>56</height>\n'
            f'\t\t\t\t<aspectratio>keep</aspectratio>\n\t\t\t\t<colordiffuse>grey</colordiffuse>\n'
            f'\t\t\t\t<texture>$VAR[MediaFlagsPathVar]/{tex}</texture>\n\t\t\t\t<visible>{vis}</visible>\n\t\t\t</control>\n')

SHARED = '''	<!-- jf-player shared pieces (tools/kodi/skin_patch.py) -->
	<include name="JFRatingBadge">
		<control type="group">
			<left>128</left>
			<top>256</top>
			<visible>!String.IsEmpty(ListItem.Rating)</visible>
			<control type="image">
				<width>66</width>
				<height>36</height>
				<texture colordiffuse="CC000000">colors/white.png</texture>
			</control>
			<control type="label">
				<width>66</width>
				<height>36</height>
				<align>center</align>
				<aligny>center</aligny>
				<font>font14_textbox</font>
				<textcolor>FFFFD54F</textcolor>
				<label>$INFO[ListItem.Rating]</label>
			</control>
		</control>
	</include>
	<include name="JFMediaFlags">
		<control type="grouplist">
			<width>650</width>
			<height>56</height>
			<itemgap>10</itemgap>
			<orientation>horizontal</orientation>
			<usecontrolcoords>true</usecontrolcoords>
''' + flag('resolution/$INFO[ListItem.VideoResolution,,.png]', '!String.IsEmpty(ListItem.VideoResolution)') \
    + flag('$INFO[ListItem.HdrType,hdr/,.png]', '!String.IsEmpty(ListItem.HdrType)') \
    + flag('videocodec/$VAR[SourceFlagVar]', '!String.IsEmpty(ListItem.VideoCodec)') \
    + flag('audiocodec/$VAR[AudioCodecFlagVar]', '!String.IsEmpty(ListItem.AudioCodec)') \
    + flag('audiochannels/$INFO[ListItem.AudioChannels,,.png]', '!String.IsEmpty(ListItem.AudioChannels)') \
    + '''		</control>
	</include>
'''

# Includes.xml: shared definitions
s = load("Includes.xml")
s = once(s, "</includes>", SHARED + "</includes>")
save("Includes.xml", s)

# InfoWall (view 51): plot shorter, flag row under it, badge on every poster (default layout)
s = load("View_51_InfoWall.xml")
s = once(s, "\t\t\t\t\t<top>555</top>\n\t\t\t\t\t<left>15</left>\n\t\t\t\t\t<width>650</width>\n\t\t\t\t\t<height>343</height>",
            "\t\t\t\t\t<top>555</top>\n\t\t\t\t\t<left>15</left>\n\t\t\t\t\t<width>650</width>\n\t\t\t\t\t<height>273</height>")
s = once(s, '\t\t\t\t<control type="scrollbar" id="95161">',
            '\t\t\t\t<control type="group">\n\t\t\t\t\t<left>15</left>\n\t\t\t\t\t<top>840</top>\n'
            '\t\t\t\t\t<include>JFMediaFlags</include>\n\t\t\t\t</control>\n'
            '\t\t\t\t<control type="scrollbar" id="95161">')
pat = re.compile(r'(\t+)<include condition="Skin.HasSetting\(Disable.UnwatchedIcon\)">UnwatchedIcon</include>\n(\t+)</control>\n')
ms = list(pat.finditer(s))[:2]   # default itemlayout + focusedlayout
assert len(ms) == 2
for m in reversed(ms):
    s = s[:m.end()] + m.group(2) + "<include>JFRatingBadge</include>\n" + s[m.end():]
save("View_51_InfoWall.xml", s)

# Home rows (PortraitArt widgets): same badge
s = load("Includes_Widgets.xml")
i = s.index('<include name="PortraitArt">'); j = s.index("\n\t</include>", i)
blk = s[i:j]
anchor = "<left>$PARAM[leftArt]</left>\n"
assert blk.count(anchor) == 2
pos, parts = 0, []
for _ in range(2):   # after the poster image (drawn on top of it), in item + focused layout
    a = blk.index(anchor, pos); e = blk.index("</control>\n", a) + len("</control>\n")
    parts.append(blk[pos:e] + "\t\t\t\t\t<include>JFRatingBadge</include>\n"); pos = e
blk = "".join(parts) + blk[pos:]
s = s[:i] + blk + s[j:]
save("Includes_Widgets.xml", s)
print("patched 3 files into", out)
