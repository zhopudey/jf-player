import sys,re
p=sys.argv[1]; s=open(p).read()
old='''					<top>555</top>
					<left>15</left>
					<width>650</width>
					<height>343</height>'''
assert s.count(old)==1
s=s.replace(old,old.replace('<height>343</height>','<height>273</height>'))
def img(tex,vis):
    v=f'\n\t\t\t\t\t\t<visible>{vis}</visible>' if vis else ''
    return f'''					<control type="image">
						<width>120</width>
						<height>56</height>
						<aspectratio>keep</aspectratio>
						<colordiffuse>grey</colordiffuse>
						<texture>$VAR[MediaFlagsPathVar]/{tex}</texture>{v}
					</control>
'''
row='''				<!-- jf-player: media flag row (2026-11-26) -->
				<control type="grouplist">
					<left>15</left>
					<top>840</top>
					<width>650</width>
					<height>56</height>
					<itemgap>10</itemgap>
					<orientation>horizontal</orientation>
					<usecontrolcoords>true</usecontrolcoords>
'''+img('resolution/$INFO[ListItem.VideoResolution,,.png]','!String.IsEmpty(ListItem.VideoResolution)')\
 +img('$INFO[ListItem.HdrType,hdr/,.png]','!String.IsEmpty(ListItem.HdrType)')\
 +img('videocodec/$VAR[SourceFlagVar]','!String.IsEmpty(ListItem.VideoCodec)')\
 +img('audiocodec/$VAR[AudioCodecFlagVar]','!String.IsEmpty(ListItem.AudioCodec)')\
 +img('audiochannels/$INFO[ListItem.AudioChannels,,.png]','!String.IsEmpty(ListItem.AudioChannels)')\
 +'''				</control>
'''
anchor='				<control type="scrollbar" id="95161">'
assert s.find(anchor)<s.find("<control type=\"panel\" id=\"51\">")
s=s.replace(anchor,row+anchor,1)
open(p,'w').write(s)
