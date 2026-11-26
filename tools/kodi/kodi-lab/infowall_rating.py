import sys,re
p=sys.argv[1]; s=open(p).read()
if 'jf-player: rating badge' in s: sys.exit('already patched')
def badge(ind):
    t='\t'*ind
    return f'''{t}<!-- jf-player: rating badge -->
{t}<control type="group">
{t}	<left>128</left>
{t}	<top>256</top>
{t}	<visible>!String.IsEmpty(ListItem.Rating)</visible>
{t}	<control type="image">
{t}		<width>66</width>
{t}		<height>36</height>
{t}		<texture colordiffuse="CC000000">colors/white.png</texture>
{t}	</control>
{t}	<control type="label">
{t}		<width>66</width>
{t}		<height>36</height>
{t}		<align>center</align>
{t}		<aligny>center</aligny>
{t}		<font>font14_textbox</font>
{t}		<textcolor>FFFFD54F</textcolor>
{t}		<label>$INFO[ListItem.Rating]</label>
{t}	</control>
{t}</control>
'''
pat=re.compile(r'(\t+)<include condition="Skin.HasSetting\(Disable.UnwatchedIcon\)">UnwatchedIcon</include>\n(\t+)</control>\n')
ms=list(pat.finditer(s))[:2]   # first itemlayout + focusedlayout (default InfoWall)
assert len(ms)==2
for m in reversed(ms):
    ind=len(m.group(2))
    s=s[:m.end()]+badge(ind)+s[m.end():]
open(p,'w').write(s)
