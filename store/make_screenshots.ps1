Add-Type -AssemblyName System.Drawing
$W = 1290; $H = 2796
$OUT = 'E:\AI-Projects\个人成长\10-项目\SaaS项目\grindsnore-ios\store'

function New-Night($w, $h, $c1, $c2, $c3, $c4) {
    $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, [System.Drawing.Color]::FromArgb($c1,$c2,$c3), [System.Drawing.Color]::FromArgb($c2,$c3,$c4), 60)
    $g.FillRectangle($bg, $rect)
    return @($bmp, $g)
}
function Card($g, $x, $y, $w, $h) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = 36
    $path.AddArc($x, $y, $r, $r, 180, 90); $path.AddArc($x+$w-$r, $y, $r, $r, 270, 90)
    $path.AddArc($x+$w-$r, $y+$h-$r, $r, $r, 0, 90); $path.AddArc($x, $y+$h-$r, $r, $r, 90, 90)
    $path.CloseFigure()
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40, 255, 255, 255))
    $g.FillPath($brush, $path)
}
function Txt($g, $t, $x, $y, $size, $bold, $r, $gr, $b) {
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $font = New-Object System.Drawing.Font('Segoe UI', $size, $style)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($r, $gr, $b))
    $g.DrawString($t, $font, $brush, $x, $y)
}
function CenterTxt($g, $t, $y, $size, $bold, $r, $gr, $b) {
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $font = New-Object System.Drawing.Font('Segoe UI', $size, $style)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($r, $gr, $b))
    $m = $g.MeasureString($t, $font)
    $x = ([single]($script:W) - $m.Width) / 2
    $g.DrawString($t, $font, $brush, $x, $y)
}

# shot1 主页
$c = New-Night $W $H 12 18 34 46; $bmp = $c[0]; $g = $c[1]
CenterTxt $g 'GrindSnore' 160 72 $true 255 255 255
CenterTxt $g 'Track snoring & teeth grinding' 260 40 $false 242 210 148
$moon = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 242, 199, 120))
$g.FillEllipse($moon, 530, 480, 230, 230)
$crater = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 226, 172, 90))
$g.FillEllipse($crater, 590, 540, 46, 46); $g.FillEllipse($crater, 680, 610, 30, 30)
Card $g 130 850 ($W-260) 210
CenterTxt $g 'Start Night' 915 54 $true 20 60 70
CenterTxt $g 'Phone on the bedside table — that is all' 1120 34 $false 200 210 220
Card $g 130 1160 ($W-260) 260
Txt $g 'MORNING REPORT' 190 1210 38 $true 242 210 148
Txt $g '42 grind events · 18 snore events' 190 1275 40 $false 255 255 255
Txt $g 'When it happened, how intense, what triggered it' 190 1340 30 $false 190 200 210
CenterTxt $g 'Everything stays on your phone' 1550 44 $true 242 210 148
$bmp.Save("$OUT\shot1.png", [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# shot2 晨报时间线
$c = New-Night $W $H 255 255 255 245; $bmp = $c[0]; $g = $c[1]
Txt $g 'Morning Report' 80 130 64 $true 14 116 144
Txt $g 'November 5 · 427 minutes tracked' 82 230 36 $false 110 120 130
$statY = 320
foreach ($row in @(@('Grind', '14', 'total 96s', 234, 137, 9), @('Snore', '6', 'total 41s', 79, 70, 229), @('Intensity', '62', 'avg of 100', 220, 38, 38), @('Jaw feel', 'Mild', 'self-reported', 14, 116, 144))) {
    Card $g 70 $statY 560 240; Card $g 660 $statY 560 240
    Txt $g $row[0] 110 ($statY+55) 36 $false 130 140 150
    Txt $g $row[1] 110 ($statY+110) 84 $true $row[4] $row[5] $row[6]
    Txt $g $row[2] 110 ($statY+195) 26 $false 150 160 170
    $statY += 280
}
Card $g 70 $statY ($W-140) 300
Txt $g 'When it happened' 120 ($statY+30) 40 $true 30 40 50
$colors = @(@(234,137,9),@(14,116,144),@(79,70,229),@(200,200,200),@(200,200,200),@(234,137,9),@(200,200,200),@(14,116,144),@(200,200,200),@(234,137,9))
$bx = 120
foreach ($cc in $colors) {
    $barBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($cc[0], $cc[1], $cc[2]))
    $g.FillRectangle($barBrush, $bx, ($statY+110), 82, 60)
    $bx += 98
}
Txt $g 'night start' 120 ($statY+195) 26 $false 150 160 170
Txt $g 'morning' 1030 ($statY+195) 26 $false 150 160 170
$bmp.Save("$OUT\shot2.png", [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()

# shot3 事件明细回放
$c = New-Night $W $H 255 255 255 245; $bmp = $c[0]; $g = $c[1]
Txt $g 'Event details' 80 130 64 $true 14 116 144
Txt $g 'Listen back · correct any misdetection' 82 230 36 $false 110 120 130
$evY = 330
foreach ($ev in @(@('02:14', 'Snore', '38s', 79, 70, 229), @('03:02', 'Grind', '4.2s', 234, 137, 9), @('03:45', 'Grind', '2.8s', 234, 137, 9), @('05:12', 'Snore', '51s', 79, 70, 229), @('06:03', 'Grind', '3.5s', 234, 137, 9))) {
    Card $g 70 $evY ($W-140) 220
    $playBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(14, 165, 190))
    $g.FillEllipse($playBrush, 130, ($evY+70), 80, 80)
    Txt $g '>' 155 ($evY+82) 44 $true 255 255 255
    Txt $g $ev[1] 250 ($evY+45) 44 $true $ev[4] $ev[5] $ev[6]
    Txt $g "$($ev[0])  ·  $($ev[2])" 250 ($evY+115) 32 $false 130 140 150
    Txt $g '...' 1130 ($evY+80) 44 $false 170 180 190
    $evY += 250
}
CenterTxt $g 'Hear it yourself. Wrong label? Fix it.' 1650 44 $true 14 116 144
$bmp.Save("$OUT\shot3.png", [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
Write-Output 'DONE 3 shots (GrindSnore)'
