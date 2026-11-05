# ==============================================================================
#  Npc修复网络 GUI  ·  一键恢复网络（图形界面版）
#  由 _merge.ps1 自动生成，生成时间: 2026-11-05 13:41:33
#
#  运行要求:
#    - Windows 10 / 11，自带 powershell.exe 5.1
#    - 必须管理员权限（启动器会自动申请）
#    - 必须 STA 线程（启动器已带 -STA，脚本内部也有兜底重启）
#
#  不要手改本文件。要改就改 ui/ 下的源片段，然后重跑 _merge.ps1。
# ==============================================================================
# =============================================================================
#  Npc修复网络 GUI · HOST LAYER  (ui/_host.ps1.txt)
#  ---------------------------------------------------------------------------
#  这是「宿主层」代码片段，由主控拼接进 Npc修复网络-GUI.ps1 的尾部。
#
#  硬约束：
#    * 本文件不含 param()、不含 #requires、不含任何自动执行语句
#      （只有 变量定义 + function 定义 + Set-Alias）
#    * 主控必须在脚本最后一行调用：  Initialize-Npc修复网络GUI
#    * 合并后的 Npc修复网络-GUI.ps1 必须保存为 UTF-8 **带 BOM**，
#      否则 powershell.exe 5.1 会按 ANSI 解码，全文件中文变乱码。
#      （5.1 无 BOM 时不会报错，只会静默乱码——这是本项目第一号交付事故源）
#
#  兼容目标：powershell.exe 5.1 (Desktop) 与 pwsh 7.x (Windows)
# =============================================================================


# =============================================================================
#  0. 三条 XAML 注入槽（主控合并时替换）
# =============================================================================
#  替换约定见 HOST.md §3：把 ui/_theme.xaml.txt 的全文替换 <<<THEME_XAML>>>，
#  其余两个同理。若某个文件还没产出，占位符留着不换也不会崩：
#  Normalize-XamlDictionary 会把「空 / 仍是占位符」的片段降级成空字典。

$script:XamlTheme       = @'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">

  <!-- ============================================================= -->
  <!--  Npc修复网络 v2  .  THEME LAYER  (Agent A)                      -->
  <!--  Dark / restrained / cold-accent.  No DropShadowEffect used.   -->
  <!--  All comments kept ASCII so GBK-vs-UTF8 decoding cannot break  -->
  <!--  the resource dictionary.                                      -->
  <!-- ============================================================= -->

  <!-- ============================ 1. COLORS ====================== -->
  <Color x:Key="ColorBg">#0B0E13</Color>
  <Color x:Key="ColorSurface">#12161F</Color>
  <Color x:Key="ColorSurface2">#171C26</Color>
  <Color x:Key="ColorBorder">#1E2530</Color>
  <Color x:Key="ColorBorderHi">#2A3441</Color>
  <Color x:Key="ColorAccent">#22D3EE</Color>
  <Color x:Key="ColorAccent2">#10B981</Color>
  <Color x:Key="ColorWarn">#F59E0B</Color>
  <Color x:Key="ColorDanger">#EF4444</Color>
  <Color x:Key="ColorText">#E6EDF3</Color>
  <Color x:Key="ColorTextDim">#7D8590</Color>
  <Color x:Key="ColorTextFaint">#4A525E</Color>

  <!-- ============================ 2. SOLID BRUSHES =============== -->
  <SolidColorBrush x:Key="BrushBg" Color="{StaticResource ColorBg}"/>
  <SolidColorBrush x:Key="BrushSurface" Color="{StaticResource ColorSurface}"/>
  <SolidColorBrush x:Key="BrushSurface2" Color="{StaticResource ColorSurface2}"/>
  <SolidColorBrush x:Key="BrushBorder" Color="{StaticResource ColorBorder}"/>
  <SolidColorBrush x:Key="BrushBorderHi" Color="{StaticResource ColorBorderHi}"/>
  <SolidColorBrush x:Key="BrushAccent" Color="{StaticResource ColorAccent}"/>
  <SolidColorBrush x:Key="BrushAccent2" Color="{StaticResource ColorAccent2}"/>
  <SolidColorBrush x:Key="BrushWarn" Color="{StaticResource ColorWarn}"/>
  <SolidColorBrush x:Key="BrushDanger" Color="{StaticResource ColorDanger}"/>
  <SolidColorBrush x:Key="BrushText" Color="{StaticResource ColorText}"/>
  <SolidColorBrush x:Key="BrushTextDim" Color="{StaticResource ColorTextDim}"/>
  <SolidColorBrush x:Key="BrushTextFaint" Color="{StaticResource ColorTextFaint}"/>

  <!-- ============================ 3. FONT FAMILIES =============== -->
  <FontFamily x:Key="FontUI">Microsoft YaHei UI, Segoe UI, Arial</FontFamily>
  <FontFamily x:Key="FontMono">Cascadia Mono, Consolas, Courier New</FontFamily>

  <!-- ============================ 4. GRADIENT / GLOW BRUSHES ===== -->
  <!-- 4.1 Progress bar fill: deep cyan -> lit cyan -> pale tip -->
  <LinearGradientBrush x:Key="BrushAccentGradient" StartPoint="0,0.5" EndPoint="1,0.5">
    <GradientStop Color="#FF0E86A3" Offset="0"/>
    <GradientStop Color="#FF22D3EE" Offset="0.55"/>
    <GradientStop Color="#FF67E8F9" Offset="1"/>
  </LinearGradientBrush>

  <!-- 4.2 Top radial halo. alpha 0x14 = 7.8% -> inside the 6%~12% budget -->
  <RadialGradientBrush x:Key="BrushGlowTop" Center="0.5,0" GradientOrigin="0.5,0"
                       RadiusX="0.62" RadiusY="1.02">
    <GradientStop Color="#1422D3EE" Offset="0"/>
    <GradientStop Color="#0C22D3EE" Offset="0.42"/>
    <GradientStop Color="#040B0E13" Offset="0.78"/>
    <GradientStop Color="#000B0E13" Offset="1"/>
  </RadialGradientBrush>

  <!-- 4.3 Ring outer glow. Radial ring: hollow center, cyan band, fade out.
       Ring radius 84px sits on a 200px ellipse => fraction 0.84

       注意 GradientOrigin 刻意偏离 Center（0.545 vs 0.5）。
       如果两者同心，这个径向渐变 + Ellipse 就是个旋转对称图形，
       Sb.RingSpin 转 360 度每帧长得一模一样，动画等于空转白烧 GPU。
       偏心 4.5% 后旋转会产生极微弱的流动感，既保住环形柔和观感，
       又让 Running 态的旋转动画真正有视觉产出。 -->
  <RadialGradientBrush x:Key="BrushRingGlow" Center="0.5,0.5" GradientOrigin="0.545,0.545"
                       RadiusX="0.5" RadiusY="0.5">
    <GradientStop Color="#0022D3EE" Offset="0"/>
    <GradientStop Color="#0022D3EE" Offset="0.60"/>
    <GradientStop Color="#3D22D3EE" Offset="0.82"/>
    <GradientStop Color="#1222D3EE" Offset="0.93"/>
    <GradientStop Color="#0022D3EE" Offset="1"/>
  </RadialGradientBrush>

  <!-- 4.4 Primary button face -->
  <LinearGradientBrush x:Key="BrushButtonPrimary" StartPoint="0,0" EndPoint="0,1">
    <GradientStop Color="#FF2FE2F7" Offset="0"/>
    <GradientStop Color="#FF22D3EE" Offset="0.52"/>
    <GradientStop Color="#FF14B4CE" Offset="1"/>
  </LinearGradientBrush>

  <!-- 4.5 Primary button hover face (brightness lift, no size change) -->
  <LinearGradientBrush x:Key="BrushButtonPrimaryHover" StartPoint="0,0" EndPoint="0,1">
    <GradientStop Color="#FF6CEFFC" Offset="0"/>
    <GradientStop Color="#FF3FE0F4" Offset="0.52"/>
    <GradientStop Color="#FF27C6DF" Offset="1"/>
  </LinearGradientBrush>

  <!-- 4.6 Window hairline frame -->
  <LinearGradientBrush x:Key="BrushWindowBorder" StartPoint="0,0" EndPoint="1,1">
    <GradientStop Color="#FF33404F" Offset="0"/>
    <GradientStop Color="#FF1C232E" Offset="0.45"/>
    <GradientStop Color="#FF161C25" Offset="1"/>
  </LinearGradientBrush>

  <!-- ============================ 5. LOG LEVEL BRUSHES =========== -->
  <SolidColorBrush x:Key="BrushLogOk" Color="{StaticResource ColorAccent2}"/>
  <SolidColorBrush x:Key="BrushLogInfo" Color="{StaticResource ColorText}"/>
  <SolidColorBrush x:Key="BrushLogWarn" Color="{StaticResource ColorWarn}"/>
  <SolidColorBrush x:Key="BrushLogErr" Color="{StaticResource ColorDanger}"/>
  <SolidColorBrush x:Key="BrushLogDim" Color="{StaticResource ColorTextFaint}"/>

  <!-- ============================ 6. GEOMETRY ICONS ============== -->
  <Geometry x:Key="Geo.IconMinimize">M 0,0 L 10,0</Geometry>
  <Geometry x:Key="Geo.IconClose">M 0,0 L 10,10 M 10,0 L 0,10</Geometry>
  <Geometry x:Key="Geo.IconCheck">M 0,5 L 4,9 L 11,0</Geometry>
  <Geometry x:Key="Geo.IconAlert">M 6,0 L 12,11 L 0,11 Z</Geometry>
  <Geometry x:Key="Geo.IconShield">M 6,0 L 12,3 L 12,7 C 12,10 6,12 6,12 C 6,12 0,10 0,7 L 0,3 Z</Geometry>
  <Geometry x:Key="Geo.IconRefresh">M 10,3 A 4,4 0 1 0 11,7</Geometry>

  <!-- ============================ 7. STYLE : WINDOW ============== -->
  <Style x:Key="Style.Window" TargetType="Window">
    <Setter Property="Background" Value="{StaticResource BrushBg}"/>
    <Setter Property="Foreground" Value="{StaticResource BrushText}"/>
    <Setter Property="FontFamily" Value="{StaticResource FontUI}"/>
    <Setter Property="FontSize" Value="13"/>
    <Setter Property="UseLayoutRounding" Value="True"/>
    <Setter Property="SnapsToDevicePixels" Value="True"/>
    <Setter Property="TextOptions.TextFormattingMode" Value="Display"/>
    <Setter Property="TextOptions.TextRenderingMode" Value="ClearType"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Window">
          <Border Background="{TemplateBinding Background}"
                  BorderBrush="{StaticResource BrushWindowBorder}"
                  BorderThickness="1"
                  SnapsToDevicePixels="True">
            <AdornerDecorator>
              <ContentPresenter/>
            </AdornerDecorator>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <!-- ============================ 8. STYLE : TITLEBAR BUTTON ===== -->
  <!-- Tag="close" on the close button swaps the hover fill to danger red. -->
  <Style x:Key="Style.TitleBarButton" TargetType="Button">
    <Setter Property="Width" Value="28"/>
    <Setter Property="Height" Value="28"/>
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="BorderThickness" Value="0"/>
    <Setter Property="Padding" Value="0"/>
    <Setter Property="Foreground" Value="{StaticResource BrushTextDim}"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="Bg"
                  Background="{TemplateBinding Background}"
                  CornerRadius="6"
                  SnapsToDevicePixels="True">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
              <Setter TargetName="Bg" Property="Background" Value="{StaticResource BrushBorder}"/>
            </Trigger>
            <Trigger Property="IsPressed" Value="True">
              <Setter TargetName="Bg" Property="Background" Value="{StaticResource BrushBorderHi}"/>
            </Trigger>
            <MultiTrigger>
              <MultiTrigger.Conditions>
                <Condition Property="Tag" Value="close"/>
                <Condition Property="IsMouseOver" Value="True"/>
              </MultiTrigger.Conditions>
              <Setter TargetName="Bg" Property="Background" Value="{StaticResource BrushDanger}"/>
            </MultiTrigger>
            <Trigger Property="IsEnabled" Value="False">
              <Setter TargetName="Bg" Property="Opacity" Value="0.4"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <!-- ============================ 9. STYLE : PRIMARY BUTTON ====== -->
  <Style x:Key="Style.PrimaryButton" TargetType="Button">
    <Setter Property="Height" Value="40"/>
    <Setter Property="MinWidth" Value="96"/>
    <Setter Property="FontFamily" Value="{StaticResource FontUI}"/>
    <Setter Property="FontSize" Value="13"/>
    <Setter Property="FontWeight" Value="SemiBold"/>
    <Setter Property="Foreground" Value="#FF04161B"/>
    <Setter Property="Background" Value="{StaticResource BrushButtonPrimary}"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="Bd"
                  Background="{TemplateBinding Background}"
                  CornerRadius="8"
                  SnapsToDevicePixels="True">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="16,0"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
              <Setter TargetName="Bd" Property="Background" Value="{StaticResource BrushButtonPrimaryHover}"/>
            </Trigger>
            <Trigger Property="IsPressed" Value="True">
              <Setter TargetName="Bd" Property="Opacity" Value="0.86"/>
            </Trigger>
            <Trigger Property="IsEnabled" Value="False">
              <Setter TargetName="Bd" Property="Opacity" Value="0.4"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <!-- ============================ 10. STYLE : GHOST BUTTON ======= -->
  <Style x:Key="Style.GhostButton" TargetType="Button">
    <Setter Property="Height" Value="40"/>
    <Setter Property="MinWidth" Value="96"/>
    <Setter Property="FontFamily" Value="{StaticResource FontUI}"/>
    <Setter Property="FontSize" Value="13"/>
    <Setter Property="Foreground" Value="{StaticResource BrushText}"/>
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="BorderBrush" Value="{StaticResource BrushBorderHi}"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="Bd"
                  Background="{TemplateBinding Background}"
                  BorderBrush="{TemplateBinding BorderBrush}"
                  BorderThickness="{TemplateBinding BorderThickness}"
                  CornerRadius="8"
                  SnapsToDevicePixels="True">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="16,0"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
              <Setter TargetName="Bd" Property="BorderBrush" Value="{StaticResource BrushAccent}"/>
              <Setter TargetName="Bd" Property="Background" Value="{StaticResource BrushSurface2}"/>
            </Trigger>
            <Trigger Property="IsPressed" Value="True">
              <Setter TargetName="Bd" Property="Opacity" Value="0.82"/>
            </Trigger>
            <Trigger Property="IsEnabled" Value="False">
              <Setter TargetName="Bd" Property="Opacity" Value="0.4"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <!-- ============================ 11. STYLE : CARD =============== -->
  <Style x:Key="Style.Card" TargetType="Border">
    <Setter Property="Background" Value="{StaticResource BrushSurface}"/>
    <Setter Property="BorderBrush" Value="{StaticResource BrushBorder}"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="CornerRadius" Value="10"/>
    <Setter Property="SnapsToDevicePixels" Value="True"/>
  </Style>

  <!-- ============================ 12. STYLE : SCROLLBAR ========== -->
  <!-- 6px wide, radius-3 thumb, no arrow buttons, page-click on track.
       Vertical by default; horizontal falls back to a 6px thin bar. -->
  <Style x:Key="Style.ScrollBar" TargetType="ScrollBar">
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="Width" Value="6"/>
    <Setter Property="MinWidth" Value="6"/>
    <Setter Property="Margin" Value="0"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ScrollBar">
          <Grid x:Name="Root" Background="Transparent" SnapsToDevicePixels="True">
            <Track x:Name="PART_Track"
                   Orientation="{TemplateBinding Orientation}"
                   IsDirectionReversed="True"
                   Focusable="False">
              <Track.DecreaseRepeatButton>
                <RepeatButton Command="ScrollBar.PageUpCommand"
                              Focusable="False"
                              Opacity="0"
                              IsTabStop="False"/>
              </Track.DecreaseRepeatButton>
              <Track.Thumb>
                <Thumb MinHeight="28" Focusable="False">
                  <Thumb.Template>
                    <ControlTemplate TargetType="Thumb">
                      <Border x:Name="ThumbBd"
                              Background="#FF2A3441"
                              CornerRadius="3"
                              SnapsToDevicePixels="True"/>
                      <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                          <Setter TargetName="ThumbBd" Property="Background" Value="#FF3A4654"/>
                        </Trigger>
                        <Trigger Property="IsDragging" Value="True">
                          <Setter TargetName="ThumbBd" Property="Background" Value="#FF4A586A"/>
                        </Trigger>
                      </ControlTemplate.Triggers>
                    </ControlTemplate>
                  </Thumb.Template>
                </Thumb>
              </Track.Thumb>
              <Track.IncreaseRepeatButton>
                <RepeatButton Command="ScrollBar.PageDownCommand"
                              Focusable="False"
                              Opacity="0"
                              IsTabStop="False"/>
              </Track.IncreaseRepeatButton>
            </Track>
          </Grid>
          <ControlTemplate.Triggers>
            <Trigger Property="Orientation" Value="Horizontal">
              <Setter TargetName="PART_Track" Property="IsDirectionReversed" Value="False"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
    <Style.Triggers>
      <Trigger Property="Orientation" Value="Horizontal">
        <Setter Property="Width" Value="Auto"/>
        <Setter Property="Height" Value="6"/>
        <Setter Property="MinHeight" Value="6"/>
      </Trigger>
    </Style.Triggers>
  </Style>

  <!-- ============================ 13. STYLE : LOG ITEM =========== -->
  <Style x:Key="Style.LogItem" TargetType="ListBoxItem">
    <Setter Property="Height" Value="20"/>
    <Setter Property="Padding" Value="12,0"/>
    <Setter Property="Foreground" Value="{StaticResource BrushText}"/>
    <Setter Property="FontFamily" Value="{StaticResource FontMono}"/>
    <Setter Property="FontSize" Value="12"/>
    <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
    <Setter Property="VerticalContentAlignment" Value="Center"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ListBoxItem">
          <Border x:Name="Bd"
                  Background="Transparent"
                  Padding="{TemplateBinding Padding}"
                  SnapsToDevicePixels="True">
            <ContentPresenter HorizontalAlignment="Stretch" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
              <Setter TargetName="Bd" Property="Background" Value="{StaticResource BrushSurface2}"/>
            </Trigger>
            <Trigger Property="IsSelected" Value="True">
              <Setter TargetName="Bd" Property="Background" Value="Transparent"/>
            </Trigger>
            <Trigger Property="IsEnabled" Value="False">
              <Setter Property="Opacity" Value="0.5"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <!-- ============================ 14. STYLE : LOG LIST =========== -->
  <!-- The ListBox itself never scrolls: the layout wraps it in ScrollViewer
       LogScroll, so the inner one is disabled on purpose. -->
  <Style x:Key="Style.LogList" TargetType="ListBox">
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="BorderThickness" Value="0"/>
    <Setter Property="Foreground" Value="{StaticResource BrushText}"/>
    <Setter Property="FontFamily" Value="{StaticResource FontMono}"/>
    <Setter Property="FontSize" Value="12"/>
    <Setter Property="ItemContainerStyle" Value="{StaticResource Style.LogItem}"/>
    <Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Disabled"/>
    <Setter Property="ScrollViewer.VerticalScrollBarVisibility" Value="Disabled"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ListBox">
          <ScrollViewer Focusable="False"
                        Padding="0"
                        HorizontalScrollBarVisibility="Disabled"
                        VerticalScrollBarVisibility="Disabled"
                        CanContentScroll="False">
            <ScrollViewer.Resources>
              <Style TargetType="ScrollBar" BasedOn="{StaticResource Style.ScrollBar}"/>
            </ScrollViewer.Resources>
            <ItemsPresenter/>
          </ScrollViewer>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <!-- ============================ 15. STYLE : PROGRESS BAR ======= -->
  <!-- PART_Track + PART_Indicator are mandatory: ProgressBar itself
       computes PART_Indicator.Width from PART_Track.ActualWidth. -->
  <Style x:Key="Style.CustomProgressBar" TargetType="ProgressBar">
    <Setter Property="Height" Value="6"/>
    <Setter Property="Minimum" Value="0"/>
    <Setter Property="Maximum" Value="100"/>
    <Setter Property="Background" Value="{StaticResource BrushBorder}"/>
    <Setter Property="Foreground" Value="{StaticResource BrushAccent}"/>
    <Setter Property="BorderThickness" Value="0"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ProgressBar">
          <Grid x:Name="Root" Background="Transparent" SnapsToDevicePixels="True">
            <Border x:Name="PART_Track"
                    Background="{TemplateBinding Background}"
                    CornerRadius="3"
                    Height="6"
                    VerticalAlignment="Center"
                    SnapsToDevicePixels="True"/>
            <Border x:Name="PART_Indicator"
                    Background="{StaticResource BrushAccentGradient}"
                    CornerRadius="3"
                    Height="6"
                    HorizontalAlignment="Left"
                    VerticalAlignment="Center"
                    SnapsToDevicePixels="True"/>
          </Grid>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <!-- ============================ 16. STYLE : TOOLTIP ============ -->
  <Style x:Key="Style.ToolTip" TargetType="ToolTip">
    <Setter Property="Background" Value="{StaticResource BrushSurface2}"/>
    <Setter Property="Foreground" Value="{StaticResource BrushText}"/>
    <Setter Property="BorderBrush" Value="{StaticResource BrushBorderHi}"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="FontFamily" Value="{StaticResource FontUI}"/>
    <Setter Property="FontSize" Value="11"/>
    <Setter Property="HasDropShadow" Value="False"/>
    <Setter Property="Padding" Value="8,5"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ToolTip">
          <Border Background="{TemplateBinding Background}"
                  BorderBrush="{TemplateBinding BorderBrush}"
                  BorderThickness="{TemplateBinding BorderThickness}"
                  CornerRadius="6"
                  Padding="{TemplateBinding Padding}"
                  SnapsToDevicePixels="True">
            <ContentPresenter/>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

</ResourceDictionary>

'@
$script:XamlAnimations  = @'
<!--
  ============================================================================
  Npc修复网络 GUI  /  Motion layer  /  Owner: Agent B
  File : ui/_animations.xaml.txt
  Parse: [Windows.Markup.XamlReader]::Parse(Get-Content -Raw ...)  ->  ResourceDictionary
  ============================================================================
  HOST CONTRACT (full spec in ui/MOTION.md):

  1. NO Storyboard in this dictionary carries a target-name attribute.
     A target name cannot resolve here: a ResourceDictionary has no NameScope.
     The host MUST do, for every start:
         $sb = $res.Clone()
         [Windows.Media.Animation.Storyboard]::SetTarget($sb, $target)
         foreach ($c in $sb.Children) { [Storyboard]::SetTarget($c, $target) }
         $sb.Begin($window, $true)          # isControllable = $true
     and for every stop:
         $sb.Stop($window); $sb.Remove($window)

  2. Every RenderTransform property path below needs a CONCRETE transform
     instance already assigned to the target element, otherwise the animation
     silently does nothing (no exception, no effect). Prerequisite table:
     ui/MOTION.md -> section 3 "Host preconditions".

  3. BASE VALUE RULE. All FillBehavior=Stop storyboards end on the element's
     base value, therefore the base value must already equal the FINAL state:
         PanelMain  Opacity = 1   RenderTransform.(TranslateTransform.Y) = 0
         Log row    Opacity = 1   RenderTransform.(TranslateTransform.X) = 0
     The START state is carried by From="..." inside the animation, never by
     the base value. Getting this backwards makes the panel vanish on arrival.

  4. All comments are ASCII on purpose: the host reads this .txt with
     Get-Content -Raw under PowerShell 5.1, whose default encoding mangles CJK.

  5. WPF ships no linear easing class (there is no Linear*Ease type at all).
     Linear motion means: simply omit the EasingFunction. Never invent
     Ease.Linear or any drop-in replacement class; XAML parsing would fail.
  ============================================================================
-->
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">

    <!-- ==================================================================
         1. SHARED EASING  (referenced by StaticResource, declared first)
         ================================================================== -->

    <CubicEase x:Key="Ease.Standard" EasingMode="EaseOut"/>
    <SineEase  x:Key="Ease.Sine"     EasingMode="EaseInOut"/>


    <!-- ==================================================================
         2. Sb.IdlePulse
            Target : StatusDot
            Props  : Opacity
            Path   : 0.35 -> 1.0 -> 0.35
            Timing : 1000 ms per leg, AutoReverse => 2000 ms round trip, Forever
            Easing : Ease.Sine (EaseInOut)
            Stop   : entering any non-Idle state
         ================================================================== -->
    <Storyboard x:Key="Sb.IdlePulse" FillBehavior="Stop">
        <DoubleAnimation Storyboard.TargetProperty="Opacity"
                         From="0.35" To="1"
                         Duration="0:0:1"
                         AutoReverse="True"
                         RepeatBehavior="Forever"
                         FillBehavior="Stop"
                         EasingFunction="{StaticResource Ease.Sine}"/>
    </Storyboard>


    <!-- ==================================================================
         3. Sb.RingSpin
            Target : RingGlow  (Ellipse)
            Props  : RenderTransform.(RotateTransform.Angle)
            Path   : 0 -> 360
            Timing : 3000 ms per revolution, Forever
            Easing : NONE. Linear by definition. Adding an easing makes the
                     glow visibly stutter once per revolution.
            Needs  : RingGlow.RenderTransform = RotateTransform,
                     RingGlow.RenderTransformOrigin = "0.5,0.5"
            Stop   : leaving Running
         ================================================================== -->
    <Storyboard x:Key="Sb.RingSpin" FillBehavior="Stop">
        <DoubleAnimation Storyboard.TargetProperty="(UIElement.RenderTransform).(RotateTransform.Angle)"
                         From="0" To="360"
                         Duration="0:0:3"
                         RepeatBehavior="Forever"
                         FillBehavior="Stop"/>
    </Storyboard>


    <!-- ==================================================================
         4. Sb.RunningBreath
            Target : RingGlow
            Props  : Opacity
            Path   : 0.25 -> 0.6 -> 0.25
            Timing : 900 ms per leg, AutoReverse => 1800 ms round trip, Forever
            Easing : Ease.Sine
            Note   : runs concurrently with Sb.RingSpin because they never touch
                     the same property (Opacity vs RotateTransform).
            Stop   : leaving Running
         ================================================================== -->
    <Storyboard x:Key="Sb.RunningBreath" FillBehavior="Stop">
        <DoubleAnimation Storyboard.TargetProperty="Opacity"
                         From="0.25" To="0.6"
                         Duration="0:0:0.9"
                         AutoReverse="True"
                         RepeatBehavior="Forever"
                         FillBehavior="Stop"
                         EasingFunction="{StaticResource Ease.Sine}"/>
    </Storyboard>


    <!-- ==================================================================
         5. Sb.PanelFadeIn
            Target : PanelMain
            Props  : Opacity 0 -> 1
                     RenderTransform.(TranslateTransform.Y) 12 -> 0
            Timing : 420 ms, one shot, FillBehavior=Stop
            Easing : Ease.Standard (CubicEase EaseOut)
            Needs  : PanelMain.RenderTransform = TranslateTransform,
                     PanelMain.RenderTransformOrigin = "0.5,0"
                     PanelMain base Opacity = 1, base Translate.Y = 0
            Stop   : never by itself; host Stops+Removes it on state reset only
         ================================================================== -->
    <Storyboard x:Key="Sb.PanelFadeIn" FillBehavior="Stop">
        <DoubleAnimation Storyboard.TargetProperty="Opacity"
                         From="0" To="1"
                         Duration="0:0:0.42"
                         FillBehavior="Stop"
                         EasingFunction="{StaticResource Ease.Standard}"/>
        <DoubleAnimation Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.Y)"
                         From="12" To="0"
                         Duration="0:0:0.42"
                         FillBehavior="Stop"
                         EasingFunction="{StaticResource Ease.Standard}"/>
    </Storyboard>


    <!-- ==================================================================
         6. Sb.SuccessFlash
            Target : StatusDot
            Props  : Fill.(SolidColorBrush.Color)
            Path   : current base color -> #10B981 -> current base color
            Timing : 300 ms out + 300 ms back (AutoReverse) = 600 ms total
            Easing : Ease.Standard
            Needs  : StatusDot.Fill must be a NON-FROZEN SolidColorBrush that no
                     other element shares. From is omitted on purpose so the
                     return trip lands exactly on whatever state color the host
                     has assigned. Host must mutate $StatusDot.Fill.Color, never
                     replace the brush object, or the animation hits a dead one.
            Stop   : one shot; host Stops+Removes it after 650 ms
         ================================================================== -->
    <Storyboard x:Key="Sb.SuccessFlash" FillBehavior="Stop">
        <ColorAnimation Storyboard.TargetProperty="(Shape.Fill).(SolidColorBrush.Color)"
                        To="#10B981"
                        Duration="0:0:0.3"
                        AutoReverse="True"
                        FillBehavior="Stop"
                        EasingFunction="{StaticResource Ease.Standard}"/>
    </Storyboard>


    <!-- ==================================================================
         7. Sb.FailFlash
            Same contract as Sb.SuccessFlash, flash color #EF4444.
         ================================================================== -->
    <Storyboard x:Key="Sb.FailFlash" FillBehavior="Stop">
        <ColorAnimation Storyboard.TargetProperty="(Shape.Fill).(SolidColorBrush.Color)"
                        To="#EF4444"
                        Duration="0:0:0.3"
                        AutoReverse="True"
                        FillBehavior="Stop"
                        EasingFunction="{StaticResource Ease.Standard}"/>
    </Storyboard>


    <!-- ==================================================================
         8. Sb.LogRowIn
            Target : the newly inserted log row (ListBoxItem container, or the
                     root element of its DataTemplate)
            Props  : Opacity 0 -> 1
                     RenderTransform.(TranslateTransform.X) -8 -> 0
            Timing : 200 ms, one shot, FillBehavior=Stop
            Easing : Ease.Standard
            Needs  : row base Opacity = 1, base Translate.X = 0
            Rule   : ONE ROW PER BATCH. When 5 rows land together only the newest
                     one plays this; the other four are inserted already settled.
         ================================================================== -->
    <Storyboard x:Key="Sb.LogRowIn" FillBehavior="Stop">
        <DoubleAnimation Storyboard.TargetProperty="Opacity"
                         From="0" To="1"
                         Duration="0:0:0.2"
                         FillBehavior="Stop"
                         EasingFunction="{StaticResource Ease.Standard}"/>
        <DoubleAnimation Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.X)"
                         From="-8" To="0"
                         Duration="0:0:0.2"
                         FillBehavior="Stop"
                         EasingFunction="{StaticResource Ease.Standard}"/>
    </Storyboard>


    <!-- ==================================================================
         9. Sb.ButtonHoverIn
            Target : StartButton / RollbackButton / MinButton / CloseButton
            Props  : Opacity 1.0 -> 0.92
            Timing : 140 ms, FillBehavior=HoldEnd (must hold while hovered)
            Easing : Ease.Standard
            Stop   : MouseLeave -> host runs Sb.ButtonHoverOut
         ================================================================== -->
    <Storyboard x:Key="Sb.ButtonHoverIn" FillBehavior="HoldEnd">
        <DoubleAnimation Storyboard.TargetProperty="Opacity"
                         From="1" To="0.92"
                         Duration="0:0:0.14"
                         FillBehavior="HoldEnd"
                         EasingFunction="{StaticResource Ease.Standard}"/>
    </Storyboard>


    <!-- ==================================================================
         10. Sb.ButtonHoverOut
             Target : same buttons
             Props  : Opacity 0.92 -> 1.0
             Timing : 140 ms, FillBehavior=HoldEnd (lands exactly on base 1.0)
         ================================================================== -->
    <Storyboard x:Key="Sb.ButtonHoverOut" FillBehavior="HoldEnd">
        <DoubleAnimation Storyboard.TargetProperty="Opacity"
                         From="0.92" To="1"
                         Duration="0:0:0.14"
                         FillBehavior="HoldEnd"
                         EasingFunction="{StaticResource Ease.Standard}"/>
    </Storyboard>


    <!-- ==================================================================
         11. Sb.ButtonHover  (contract alias, CONTRACT.md 3.6 names this key)
             Identical behaviour to Sb.ButtonHoverIn. Kept so that either name
             works from the host. Prefer the In/Out pair.
         ================================================================== -->
    <Storyboard x:Key="Sb.ButtonHover" FillBehavior="HoldEnd">
        <DoubleAnimation Storyboard.TargetProperty="Opacity"
                         From="1" To="0.92"
                         Duration="0:0:0.14"
                         FillBehavior="HoldEnd"
                         EasingFunction="{StaticResource Ease.Standard}"/>
    </Storyboard>


    <!-- ==================================================================
         12. Sb.ProgressGlowSweep
             Target : ProgressGlow (Border, the light sweep inside the bar)
             Props  : RenderTransform.(TranslateTransform.X)
             Path   : -200 -> 400
             Timing : 1400 ms per sweep, Forever
             Easing : NONE (linear sweep, anything else looks like a wobble)
             Needs  : ProgressGlow.Width = 200
                      ProgressGlow.RenderTransform = TranslateTransform
                      ProgressGlow.RenderTransformOrigin = "0,0.5"
                      the bar's clipping parent must ClipToBounds="True"
                      so the sweep never paints outside the track
             Stop   : leaving Running
         ================================================================== -->
    <Storyboard x:Key="Sb.ProgressGlowSweep" FillBehavior="Stop">
        <DoubleAnimation Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.X)"
                         From="-200" To="400"
                         Duration="0:0:1.4"
                         RepeatBehavior="Forever"
                         FillBehavior="Stop"/>
    </Storyboard>


    <!-- ==================================================================
         13. Sb.RingSettle
             Target : RingHost (Grid, the container, NOT RingGlow)
             Props  : RenderTransform.(ScaleTransform.ScaleX)
                      RenderTransform.(ScaleTransform.ScaleY)
             Path   : 1.0 -> 1.06 -> 1.0
             Timing : 250 ms per leg, AutoReverse => 500 ms total, one shot
             Easing : Ease.Standard
             Needs  : RingHost.RenderTransform = ScaleTransform,
                      RingHost.RenderTransformOrigin = "0.5,0.5"
             Why the container: an element owns exactly one RenderTransform, and
             RingGlow already spends its slot on RotateTransform for Sb.RingSpin.
             Stop   : one shot; host Stops+Removes it after 550 ms
         ================================================================== -->
    <Storyboard x:Key="Sb.RingSettle" FillBehavior="Stop">
        <DoubleAnimation Storyboard.TargetProperty="(UIElement.RenderTransform).(ScaleTransform.ScaleX)"
                         From="1" To="1.06"
                         Duration="0:0:0.25"
                         AutoReverse="True"
                         FillBehavior="Stop"
                         EasingFunction="{StaticResource Ease.Standard}"/>
        <DoubleAnimation Storyboard.TargetProperty="(UIElement.RenderTransform).(ScaleTransform.ScaleY)"
                         From="1" To="1.06"
                         Duration="0:0:0.25"
                         AutoReverse="True"
                         FillBehavior="Stop"
                         EasingFunction="{StaticResource Ease.Standard}"/>
    </Storyboard>


    <!-- ==================================================================
         14. Sb.ParticleDrift
             Target : one particle (Ellipse inside ParticleLayer Canvas)
             Props  : RenderTransform.(TranslateTransform.Y) 0 -> -52
                      Opacity keyframed 0 -> 0.55 -> 0.35 -> 0
             Timing : 6000 ms per cycle, Forever
             Easing : linear Y, Ease.Sine on the opacity keyframes
             Needs  : particle.RenderTransform = TranslateTransform
                      particle.RenderTransformOrigin = "0.5,0.5"
                      static placement is set ONCE at creation through the
                      canvas attached positioning properties, and those are
                      never animated; only the drift rides RenderTransform
             Budget : at most 18 particles, one clock each
             Stagger: host sets a NEGATIVE BeginTime per particle
                      ($sb.BeginTime = [TimeSpan]::FromMilliseconds(-$i * 333))
                      so they do not pop in phase with each other
             Stop   : window hidden / minimized / state change to Success, Warn, Fail
         ================================================================== -->
    <Storyboard x:Key="Sb.ParticleDrift" FillBehavior="Stop">
        <DoubleAnimation Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.Y)"
                         From="0" To="-52"
                         Duration="0:0:6"
                         RepeatBehavior="Forever"
                         FillBehavior="Stop"/>
        <DoubleAnimationUsingKeyFrames Storyboard.TargetProperty="Opacity"
                                       RepeatBehavior="Forever"
                                       FillBehavior="Stop">
            <LinearDoubleKeyFrame KeyTime="0:0:0"      Value="0"/>
            <EasingDoubleKeyFrame KeyTime="0:0:1.2"    Value="0.55"
                                  EasingFunction="{StaticResource Ease.Sine}"/>
            <EasingDoubleKeyFrame KeyTime="0:0:4"      Value="0.35"
                                  EasingFunction="{StaticResource Ease.Sine}"/>
            <LinearDoubleKeyFrame KeyTime="0:0:6"      Value="0"/>
        </DoubleAnimationUsingKeyFrames>
    </Storyboard>

</ResourceDictionary>

'@
$script:XamlLayout      = @'
<Grid x:Name="RootGrid"
      xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      Background="{StaticResource BrushBg}"
      UseLayoutRounding="True"
      SnapsToDevicePixels="True"
      TextOptions.TextFormattingMode="Display">

  <!-- ============================================================= -->
  <!--  Npc修复网络 v2  .  LAYOUT LAYER  (Agent A)                     -->
  <!--  Root is the Window Content. 4 rows:                          -->
  <!--    0 TitleBar  44                                             -->
  <!--    1 PanelMain Auto  (ring + status)                          -->
  <!--    2 Log card  *                                              -->
  <!--    3 Status bar 72                                            -->
  <!--  All static copy is ENGLISH placeholder text; the host        -->
  <!--  replaces it at runtime (CONTRACT 3.8).                       -->
  <!-- ============================================================= -->

  <Grid.RowDefinitions>
    <RowDefinition Height="Auto"/>
    <RowDefinition Height="Auto"/>
    <RowDefinition Height="*"/>
    <RowDefinition Height="Auto"/>
  </Grid.RowDefinitions>

  <!-- ===================== LAYER 0 : TOP HALO ==================== -->
  <!-- Canvas Background = radial brush, so it always matches the
       window width without any binding. -->
  <Canvas x:Name="GlowLayer"
          Grid.Row="0" Grid.RowSpan="4"
          Height="260" VerticalAlignment="Top"
          Background="{StaticResource BrushGlowTop}"
          IsHitTestVisible="False"/>

  <!-- ===================== LAYER 1 : PARTICLES =================== -->
  <!-- Empty container reserved for the motion layer. Transparent
       background + no hit testing so it never steals input. -->
  <Canvas x:Name="ParticleLayer"
          Grid.Row="0" Grid.RowSpan="4"
          Background="Transparent"
          IsHitTestVisible="False"
          ClipToBounds="True"/>

  <!-- ===================== ROW 0 : TITLE BAR ===================== -->
  <Border x:Name="TitleBar"
          Grid.Row="0" Height="44"
          Background="Transparent"
          BorderBrush="{StaticResource BrushBorder}"
          BorderThickness="0,0,0,1">
    <Grid Margin="20,0,10,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>

      <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
        <Ellipse Width="4" Height="4" Fill="{StaticResource BrushAccent}" VerticalAlignment="Center"/>
        <TextBlock x:Name="TitleText" Text="Npc修复网络"
                   FontSize="13" FontWeight="SemiBold"
                   Foreground="{StaticResource BrushText}"
                   Margin="10,0,0,0" VerticalAlignment="Center"/>
        <TextBlock x:Name="VersionText" Text="v2.0"
                   FontFamily="{StaticResource FontMono}" FontSize="11"
                   Foreground="{StaticResource BrushTextFaint}"
                   Margin="10,0,0,0" VerticalAlignment="Center"/>
      </StackPanel>

      <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
        <Button x:Name="MinButton" Style="{StaticResource Style.TitleBarButton}">
          <Button.ToolTip>
            <ToolTip Content="MIN" Style="{StaticResource Style.ToolTip}"/>
          </Button.ToolTip>
          <Path Data="{StaticResource Geo.IconMinimize}"
                Stroke="{StaticResource BrushTextDim}" StrokeThickness="1.2"
                Width="10" Height="10" Stretch="None"/>
        </Button>
        <Button x:Name="CloseButton" Style="{StaticResource Style.TitleBarButton}"
                Tag="close" Margin="4,0,0,0">
          <Button.ToolTip>
            <ToolTip Content="CLOSE" Style="{StaticResource Style.ToolTip}"/>
          </Button.ToolTip>
          <Path Data="{StaticResource Geo.IconClose}"
                Stroke="{StaticResource BrushTextDim}" StrokeThickness="1.2"
                Width="10" Height="10" Stretch="None"/>
        </Button>
      </StackPanel>
    </Grid>
  </Border>

  <!-- ===================== ROW 1 : MAIN PANEL ==================== -->
  <!-- RenderTransform is pre-installed as an animation carrier for
       Sb.PanelFadeIn (opacity + 12px translate). Panel must not be
       moved by any other transform. -->
  <Grid x:Name="PanelMain" Grid.Row="1" Margin="24,20,24,0">
    <Grid.RenderTransform>
      <TranslateTransform X="0" Y="0"/>
    </Grid.RenderTransform>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="220"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <!-- ===== 1.1 ring block ===== -->
    <Grid x:Name="RingHost" Grid.Column="0"
          Width="168" Height="168"
          HorizontalAlignment="Center" VerticalAlignment="Center">

      <!-- outer glow: 200px ellipse, ring band sits at radius 84 => 0.84 -->
      <Ellipse x:Name="RingGlow"
               Width="200" Height="200"
               HorizontalAlignment="Center" VerticalAlignment="Center"
               Fill="{StaticResource BrushRingGlow}"
               Opacity="0.5"
               IsHitTestVisible="False"
               RenderTransformOrigin="0.5,0.5">
        <Ellipse.RenderTransform>
          <RotateTransform Angle="0"/>
        </Ellipse.RenderTransform>
      </Ellipse>

      <!-- track -->
      <Ellipse x:Name="RingTrack"
               Width="168" Height="168"
               HorizontalAlignment="Center" VerticalAlignment="Center"
               Stroke="{StaticResource BrushBorder}" StrokeThickness="8"
               Fill="Transparent"/>

      <!-- progress arc.
           circumference  C  = 2 * pi * 76      = 477.52
           dash unit     u  = C / StrokeThickness = 59.69
           show fraction p  -> StrokeDashArray = "{59.69*p} {59.69*(1-p)}"
           default below is p = 0.75.
           Geometry is rotated -90 so the dash start sits at 12 o'clock. -->
      <Path x:Name="RingFill"
            Width="168" Height="168"
            HorizontalAlignment="Center" VerticalAlignment="Center"
            Stroke="{StaticResource BrushAccent}" StrokeThickness="8"
            StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeDashCap="Round"
            StrokeDashArray="44.77 14.92"
            StrokeDashOffset="0">
        <Path.Data>
          <EllipseGeometry Center="84,84" RadiusX="76" RadiusY="76">
            <EllipseGeometry.Transform>
              <RotateTransform Angle="-90" CenterX="84" CenterY="84"/>
            </EllipseGeometry.Transform>
          </EllipseGeometry>
        </Path.Data>
      </Path>

      <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
        <TextBlock x:Name="RingPercentText" Text="0%"
                   FontFamily="{StaticResource FontMono}" FontSize="28"
                   Foreground="{StaticResource BrushText}"
                   HorizontalAlignment="Center" TextAlignment="Center"/>
      </StackPanel>
    </Grid>

    <!-- ===== 1.2 status block ===== -->
    <StackPanel Grid.Column="1" Margin="24,0,0,0" VerticalAlignment="Center">
      <TextBlock x:Name="StageText" Text="STEP 0 / 10"
                 FontSize="11"
                 Foreground="{StaticResource BrushTextDim}"/>
      <TextBlock x:Name="StatusText" Text="Idle"
                 FontSize="20" LineHeight="28"
                 Foreground="{StaticResource BrushText}"
                 TextWrapping="Wrap" TextTrimming="CharacterEllipsis"
                 Margin="0,6,0,0"/>
      <Grid Margin="0,18,0,0" Height="6">
        <ProgressBar x:Name="ProgressBar" Style="{StaticResource Style.CustomProgressBar}"
                     Height="6" Minimum="0" Maximum="100" Value="0"
                     VerticalAlignment="Center"/>
        <!-- sweep overlay. Own brush instance so a stop animation on
             this layer can never leak into the ProgressBar indicator. -->
        <Border x:Name="ProgressGlow"
                Height="6" CornerRadius="3"
                Opacity="0" IsHitTestVisible="False"
                VerticalAlignment="Center">
          <Border.Background>
            <LinearGradientBrush StartPoint="0,0.5" EndPoint="1,0.5">
              <GradientStop Color="#0022D3EE" Offset="0"/>
              <GradientStop Color="#8822D3EE" Offset="0.86"/>
              <GradientStop Color="#CCEAFCFF" Offset="0.94"/>
              <GradientStop Color="#0022D3EE" Offset="1"/>
            </LinearGradientBrush>
          </Border.Background>
        </Border>
      </Grid>
      <TextBlock x:Name="DetailText" Text=""
                 FontSize="12"
                 Foreground="{StaticResource BrushTextFaint}"
                 TextTrimming="CharacterEllipsis" TextWrapping="NoWrap"
                 Margin="0,10,0,0"/>
    </StackPanel>
  </Grid>

  <!-- ===================== ROW 2 : LOG CARD ====================== -->
  <Border Grid.Row="2" Style="{StaticResource Style.Card}" Margin="24,16,24,0">
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>

      <Grid Grid.Row="0" Margin="14,10,14,6">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <TextBlock x:Name="LogTitle" Grid.Column="0" Text="LOG"
                   FontFamily="{StaticResource FontMono}" FontSize="11"
                   Foreground="{StaticResource BrushTextDim}"
                   VerticalAlignment="Center"/>
        <Border Grid.Column="1" Height="1"
                Background="{StaticResource BrushBorder}"
                Margin="12,0,0,0" VerticalAlignment="Center"/>
      </Grid>

      <ScrollViewer x:Name="LogScroll" Grid.Row="1"
                    VerticalScrollBarVisibility="Auto"
                    HorizontalScrollBarVisibility="Disabled"
                    Padding="0,0,4,10"
                    Focusable="False">
        <ScrollViewer.Resources>
          <Style TargetType="ScrollBar" BasedOn="{StaticResource Style.ScrollBar}"/>
        </ScrollViewer.Resources>
        <ListBox x:Name="LogList"
                 Style="{StaticResource Style.LogList}"
                 ItemContainerStyle="{StaticResource Style.LogItem}"/>
      </ScrollViewer>
    </Grid>
  </Border>

  <!-- ===================== ROW 3 : STATUS BAR ==================== -->
  <Border Grid.Row="3" Height="72"
          Background="Transparent"
          BorderBrush="{StaticResource BrushBorder}"
          BorderThickness="0,1,0,0">
    <Grid Margin="24,0,24,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>

      <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
        <Ellipse x:Name="StatusDot"
                 Width="8" Height="8"
                 Fill="{StaticResource BrushTextFaint}"
                 VerticalAlignment="Center"
                 RenderTransformOrigin="0.5,0.5">
          <Ellipse.RenderTransform>
            <ScaleTransform ScaleX="1" ScaleY="1"/>
          </Ellipse.RenderTransform>
        </Ellipse>
        <TextBlock x:Name="StatusLabel" Text="Idle"
                   FontSize="13"
                   Foreground="{StaticResource BrushTextDim}"
                   TextTrimming="CharacterEllipsis"
                   Margin="8,0,0,0" VerticalAlignment="Center"/>
      </StackPanel>

      <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
        <Button x:Name="RollbackButton" Content="ROLLBACK"
                Style="{StaticResource Style.GhostButton}" Width="120"/>
        <Button x:Name="StartButton" Content="START"
                Style="{StaticResource Style.PrimaryButton}" Width="140" Margin="12,0,0,0"/>
      </StackPanel>
    </Grid>
  </Border>

</Grid>

'@

# 可选第四条槽：把主引擎 Npc修复网络.ps1 全文内联进来，实现「零依赖单文件」交付。
# 不替换就留字面占位符，运行时会自动跳过、改为从磁盘读同目录的 Npc修复网络.ps1。
$script:EngineInlineText = @'
<<<ENGINE_SOURCE>>>
'@


# =============================================================================
#  1. 宿主常量 / 全局状态
# =============================================================================

$script:HostVersion    = '2.0.0'
$script:AppVersion     = 'v2.0'
$script:LogLimit       = 200          # 日志行上限（契约 §4.7）
$script:FlushInterval  = 100          # UI 队列批量刷新周期 ms
$script:FlushBatch     = 40           # 单次最多消费事件数
$script:RingAnimMs     = 260          # 环形补间时长（契约 §3.6 标准时长）
$script:MaxRawLine     = 400          # 单条原始输出截断

# 环形进度的补间开关。置 $false 即退化成视觉层 DESIGN.md 的「瞬切」行为
# （只改 StrokeDashOffset 的基准值、不挂动画），一行切换，供主控对比验收。
$script:RingTweenEnabled = $true

# 总步数 = 10 个修复阶段 + 1 个验证阶段。改这一个常量就能改成 10（此时验证
# 会并入第 10 步）。默认 11 是为了让环形只在「真的验完」之后才到 100%。
$script:StageTotal      = 11

# 粒子层开关。ParticleLayer 默认是空 Canvas，动它没有视觉产出，所以默认关。
$script:EnableParticles = $false

$script:Window          = $null
$script:UiQueue         = $null
$script:RefreshTimer    = $null
$script:UiThreadId      = 0
$script:ActiveStoryboards = @{}
$script:BrushCache      = @{}
$script:FontCache       = @{}
$script:Running         = $false
$script:CurrentState    = 'Idle'
$script:Runspace        = $null
$script:Ps              = $null
$script:AsyncHandle     = $null
$script:Lang            = 'en'
$script:XmlLang         = 'en-US'
$script:RingLength      = 0.0
$script:RingDashReady   = $false
$script:HoverTarget     = $null
$script:SelfPath        = ''
$script:NoAdmin         = $false
$script:PendingDotColor = $null
$script:PendingDotTimer = $null

# 契约 §3.8：$global:GUI.L10n.zh / .en 必须可从外部点进去
if ($null -eq $global:GUI) { $global:GUI = @{} }
$global:GUI['HostVersion'] = $script:HostVersion


# =============================================================================
#  2. 双语文案表
# =============================================================================
#  所有面向用户的字符串必须从这里取，代码里不允许出现裸中文/裸英文。

$script:L10n = @{
    zh = @{
        'App.Title'            = 'Npc修复网络'
        'App.Version'          = 'v2.0'

        'Btn.Start'            = '开始修复'
        'Btn.Retry'            = '再修一次'
        'Btn.Rollback'         = '回滚设置'
        'Btn.Running'          = '修复中...'
        'Btn.Close'            = '关闭'

        'Label.Log'            = '运行日志'
        'Label.Step'           = '第 {0} 步 / 共 {1} 步'
        'Tip.Idle'             = '会把网络设置重置回正常状态，并先备份原始配置。'

        'State.Idle'           = '准备就绪，点「开始修复」'
        'State.Running'        = '正在修复网络...'
        'State.Success'        = '网络已恢复，可以上网了'
        'State.Warn'           = '部分完成，建议再试一次'
        'State.Fail'           = '本机配置已重置，可能是路由器问题'

        'Stage.1'              = '备份当前配置'
        'Stage.2'              = '清除代理劫持'
        'Stage.3'              = '清除 hosts 污染'
        'Stage.4'              = '重置网络协议栈'
        'Stage.5'              = '修复网卡绑定'
        'Stage.6'              = 'IP / DNS 归位'
        'Stage.7'              = '重启网络服务'
        'Stage.8'              = '重载网卡'
        'Stage.9'              = '重新获取地址'
        'Stage.10'             = '修复联网检测'
        'Stage.Verify'         = '验证网络状态'
        'Stage.RollbackHosts'  = '回滚 hosts 文件'
        'Stage.RollbackConfig' = '回滚网卡 IP / DNS'

        'Log.Start'            = '开始执行网络修复'
        'Log.Boot'             = 'Npc修复网络 {0} 已就绪，等待操作'
        'Log.Round2'           = '第一轮没完全通，自动开始第二轮补救'
        'Log.RescueDns'        = '公共 DNS 兜底，已设置 {0} 个网卡'
        'Log.Verify'           = '验证结果：通过 {0} / {1} 项'
        'Log.Summary'          = '成功 {0} 步 / 失败 {1} 步 / 跳过 {2} 步，耗时 {3} 秒'
        'Log.NoEngine'         = '找不到主引擎 Npc修复网络.ps1，修复功能不可用'
        'Log.NoBackup'         = '没有可回滚的备份'
        'Log.NoAdmin'          = '当前不是管理员权限，无法修改网络设置'
        'Log.RollbackDone'     = '回滚流程结束'

        'Err.NoEngine'         = '主引擎缺失，无法开始。请把 Npc修复网络.ps1 放到本程序同目录。'
        'Err.EngineParse'      = '主引擎源码解析失败'
        'Err.EngineLoad'       = '主引擎加载失败'
        'Err.WorkerStart'      = '后台线程启动失败'
        'Err.StageMissing'     = '找不到阶段函数 {0}'
        'Err.StageCrash'       = '阶段执行异常 {0}'
        'Err.Xaml'             = '界面资源加载失败，程序无法启动'
        'Err.Init'             = '界面初始化失败'

        'Ask.QuitRunning'      = '修复正在进行中，现在退出会中断后续步骤。确定要退出吗？'
        'Ask.Title'            = 'NpcNetRepair'
    }
    en = @{
        'App.Title'            = 'Npc 修复网络 - Network Repair'
        'App.Version'          = 'v2.0'

        'Btn.Start'            = 'Start Repair'
        'Btn.Retry'            = 'Retry'
        'Btn.Rollback'         = 'Rollback'
        'Btn.Running'          = 'Repairing...'
        'Btn.Close'            = 'Close'

        'Label.Log'            = 'Activity Log'
        'Label.Step'           = 'Step {0} of {1}'
        'Tip.Idle'             = 'Resets network settings to a clean state and backs up the originals first.'

        'State.Idle'           = 'Ready. Click Start Repair.'
        'State.Running'        = 'Repairing network...'
        'State.Success'        = 'Network restored. You are online.'
        'State.Warn'           = 'Partially fixed. Try again.'
        'State.Fail'           = 'Local config reset. Check your router.'

        'Stage.1'              = 'Backing up configuration'
        'Stage.2'              = 'Clearing proxy hijack'
        'Stage.3'              = 'Cleaning hosts pollution'
        'Stage.4'              = 'Resetting network stack'
        'Stage.5'              = 'Repairing adapter bindings'
        'Stage.6'              = 'Restoring IP / DNS'
        'Stage.7'              = 'Restarting network services'
        'Stage.8'              = 'Reloading adapters'
        'Stage.9'              = 'Renewing address lease'
        'Stage.10'             = 'Repairing connectivity probe'
        'Stage.Verify'         = 'Verifying connectivity'
        'Stage.RollbackHosts'  = 'Rolling back hosts file'
        'Stage.RollbackConfig' = 'Rolling back adapter IP / DNS'

        'Log.Start'            = 'Starting network repair'
        'Log.Boot'             = 'Npc修复网络 {0} ready'
        'Log.Round2'           = 'Round one incomplete, starting rescue round'
        'Log.RescueDns'        = 'Public DNS fallback applied to {0} adapter(s)'
        'Log.Verify'           = 'Verification: {0} / {1} checks passed'
        'Log.Summary'          = '{0} ok / {1} failed / {2} skipped in {3}s'
        'Log.NoEngine'         = 'Engine Npc修复网络.ps1 not found, repair unavailable'
        'Log.NoBackup'         = 'No backup available to roll back'
        'Log.NoAdmin'          = 'Not running as administrator, network changes blocked'
        'Log.RollbackDone'     = 'Rollback finished'

        'Err.NoEngine'         = 'Engine missing. Put Npc修复网络.ps1 next to this program.'
        'Err.EngineParse'      = 'Failed to parse engine source'
        'Err.EngineLoad'       = 'Failed to load engine'
        'Err.WorkerStart'      = 'Failed to start background thread'
        'Err.StageMissing'     = 'Stage function not found: {0}'
        'Err.StageCrash'       = 'Stage crashed: {0}'
        'Err.Xaml'             = 'Failed to load UI resources, cannot start'
        'Err.Init'             = 'UI initialization failed'

        'Ask.QuitRunning'      = 'A repair is running. Quitting now aborts the remaining steps. Quit anyway?'
        'Ask.Title'            = 'NpcNetRepair'
    }
}

$global:GUI['L10n'] = $script:L10n


# =============================================================================
#  3. 语言判定 + 取词
# =============================================================================
#  主控补丁（已实测）：powershell.exe 5.1 在中文系统上，UI 语言相关的三个来源
#  （线程 UICulture / $PSUICulture / Get-UICulture）统统返回 en-US，
#  一个都不能用来判语言。可信的只有 CurrentCulture / InstalledUICulture /
#  Get-WinSystemLocale / 注册表 InstallLanguage / OS 的 OSLanguage，
#  所以这里多源投票、任一命中即判中文。

function Get-UiLanguage {
    $votes = New-Object System.Collections.ArrayList
    try { [void]$votes.Add((Get-WinSystemLocale).TwoLetterISOLanguageName) } catch { }
    try { [void]$votes.Add([System.Globalization.CultureInfo]::InstalledUICulture.TwoLetterISOLanguageName) } catch { }
    try { [void]$votes.Add([System.Globalization.CultureInfo]::CurrentCulture.TwoLetterISOLanguageName) } catch { }
    try {
        $il = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\Language' -ErrorAction Stop).InstallLanguage
        if ($il -match '^(0804|0404|0c04|1004)$') { [void]$votes.Add('zh') } else { [void]$votes.Add('other') }
    } catch { }
    try {
        $ol = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).OSLanguage
        if (@(2052, 1028, 3076, 4100) -contains [int]$ol) { [void]$votes.Add('zh') } else { [void]$votes.Add('other') }
    } catch { }
    foreach ($v in $votes) { if ([string]$v -eq 'zh') { return 'zh' } }
    return 'en'
}

function T {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string]$Key,
        [Parameter(Position = 1)][object[]]$Fmt = @()
    )
    $table = $null
    try { $table = $script:L10n[$script:Lang] } catch { $table = $null }
    if ($null -eq $table) { $table = $script:L10n['en'] }
    $v = $null
    if ($table.ContainsKey($Key)) { $v = $table[$Key] }
    if ($null -eq $v) { return $Key }
    if ($null -ne $Fmt -and $Fmt.Count -gt 0) {
        try { return ([string]$v -f $Fmt) } catch { return [string]$v }
    }
    return [string]$v
}

function Initialize-HostLocalization {
    $script:Lang = Get-UiLanguage
    # 编码金丝雀：文件被按 ANSI 读坏时，中文表会和源文件对不上。
    # '开始修复' 必须是 4 个字符且首字是 U+5F00（开）。对不上就整体退英文。
    $canary = ''
    try { $canary = [string]$script:L10n['zh']['Btn.Start'] } catch { $canary = '' }
    $ok = ($canary.Length -eq 4)
    if ($ok) {
        try { if ([int]$canary[0] -ne 0x5F00) { $ok = $false } } catch { $ok = $false }
    }
    if (-not $ok) { $script:Lang = 'en' }
    if ($script:Lang -eq 'zh') { $script:XmlLang = 'zh-CN' } else { $script:XmlLang = 'en-US' }
}


# =============================================================================
#  4. 运行时初始化（程序集 / 控制台 / 线程 / 权限）
# =============================================================================

function Initialize-HostRuntime {
    $names = @('PresentationFramework', 'PresentationCore', 'WindowsBase', 'System.Xaml')
    foreach ($n in $names) {
        try { Add-Type -AssemblyName $n -ErrorAction Stop } catch { }
    }
    # 断言关键类型真的在
    $need = @(
        'System.Windows.Window',
        'System.Windows.Markup.XamlReader',
        'System.Windows.Threading.DispatcherTimer',
        'System.Windows.Media.Animation.Storyboard'
    )
    foreach ($t in $need) {
        $found = $false
        try { $found = ($null -ne ($t -as [type])) } catch { $found = $false }
        if (-not $found) { throw ('assembly type missing: ' + $t) }
    }
}

function Test-Admin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $pr = New-Object Security.Principal.WindowsPrincipal($id)
        return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Get-HostExePath {
    $p = ''
    try {
        $p = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    } catch { $p = '' }
    if ([string]::IsNullOrWhiteSpace($p)) {
        $exe = 'powershell.exe'
        try { if ($PSVersionTable.PSEdition -eq 'Core') { $exe = 'pwsh.exe' } } catch { }
        $p = Join-Path $PSHOME $exe
    }
    return $p
}

function Get-SelfPath {
    $p = ''
    try { $p = [string]$PSCommandPath } catch { $p = '' }
    if ([string]::IsNullOrWhiteSpace($p)) {
        try { $p = [string]$MyInvocation.MyCommand.Path } catch { $p = '' }
    }
    if ([string]::IsNullOrWhiteSpace($p)) {
        try {
            $a = [Environment]::GetCommandLineArgs()
            foreach ($x in $a) {
                if ($x -match '\.ps1$' -and (Test-Path -LiteralPath $x)) { $p = $x; break }
            }
        } catch { }
    }
    return $p
}

function Hide-HostConsole {
    try {
        if (-not ([System.Management.Automation.PSTypeName]'NR.WinApi').Type) {
            $sig = '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
            Add-Type -MemberDefinition $sig -Name 'WinApi' -Namespace 'NR' -ErrorAction Stop | Out-Null
        }
        $h = [NR.WinApi]::GetConsoleWindow()
        if ($h -ne [IntPtr]::Zero) { [void][NR.WinApi]::ShowWindow($h, 0) }
    } catch { }
}

function Test-StaThread {
    try {
        return ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq [System.Threading.ApartmentState]::STA)
    } catch { return $true }
}

# 返回 $true 表示「已拉起新进程，本进程应当直接退出」
function Restart-ForEnvironment {
    $self = Get-SelfPath
    $exe = Get-HostExePath
    $needSta = -not (Test-StaThread)
    $needAdmin = -not (Test-Admin)

    if ($needSta -and -not ($env:NR_STA -eq '1') -and -not [string]::IsNullOrWhiteSpace($self)) {
        $a = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $self + '"'))
        try {
            $env:NR_STA = '1'
            Start-Process -FilePath $exe -ArgumentList $a | Out-Null
            return $true
        } catch { $env:NR_STA = '' }
    }

    if ($needAdmin -and -not ($env:NR_ELEVATED -eq '1') -and -not [string]::IsNullOrWhiteSpace($self)) {
        $a = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $self + '"'))
        try {
            $env:NR_ELEVATED = '1'
            Start-Process -FilePath $exe -Verb RunAs -ArgumentList $a | Out-Null
            return $true
        } catch {
            $env:NR_ELEVATED = ''
            # 用户点了「否」或 UAC 被策略挡掉：不退出，继续建窗口，但禁用修复按钮
            return $false
        }
    }
    return $false
}


# =============================================================================
#  5. 控件 / 资源 / 画刷 / 字体 取值助手
# =============================================================================

function Get-Ctl {
    param([string]$Name = '')
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    if ($null -eq $global:GUI) { return $null }
    try {
        if ($global:GUI.ContainsKey($Name)) { return $global:GUI[$Name] }
    } catch { }
    return $null
}

function Find-Res {
    param([Parameter(Mandatory = $true)][string]$Key)
    if ($null -eq $script:Window) { return $null }
    try { return $script:Window.TryFindResource($Key) } catch { return $null }
}

function ConvertTo-Brush {
    param([string]$Hex)
    try {
        $bc = New-Object System.Windows.Media.BrushConverter
        $b = $bc.ConvertFromString($Hex)
        if ($b -is [System.Windows.Media.Brush]) { return $b }
    } catch { }
    return $null
}

# 逻辑名 -> 实际资源 Key。视觉层的命名可能是 BrushAccent / Brush.Accent /
# Brush.ColorAccent 三种风格，这里全试一遍，避免为一个名字返工。
function Get-Brush {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$FallbackHex = '#7D8590'
    )
    if ($script:BrushCache.ContainsKey($Name)) { return $script:BrushCache[$Name] }

    $cands = @(
        ('Brush' + $Name),
        ('Brush.' + $Name),
        ('Brush.Color' + $Name),
        ('Color' + $Name),
        ('Brush.Color' + $Name),
        ($Name + 'Brush'),
        ('Color.' + $Name)
    )
    foreach ($k in $cands) {
        $r = Find-Res $k
        if ($null -eq $r) { continue }
        if ($r -is [System.Windows.Media.Brush]) {
            $script:BrushCache[$Name] = $r
            return $r
        }
        if ($r -is [System.Windows.Media.Color]) {
            $b = New-Object System.Windows.Media.SolidColorBrush
            $b.Color = $r
            $script:BrushCache[$Name] = $b
            return $b
        }
    }
    $fb = ConvertTo-Brush $FallbackHex
    if ($null -ne $fb) { $script:BrushCache[$Name] = $fb }
    return $fb
}

function Get-UiFont {
    param([string]$Kind = 'Mono')
    if ($script:FontCache.ContainsKey($Kind)) { return $script:FontCache[$Kind] }

    $cands = @()
    if ($Kind -eq 'Mono') {
        $cands = @('FontMono', 'FontUI_Mono', 'Font.Mono', 'MonoFont', 'FontFamilyMono', 'Mono')
    } else {
        # 视觉层实际用的是 FontUI（大写 UI），资源 Key 区分大小写，所以两种都试
        $cands = @('FontUI', 'FontUi', 'Font.UI', 'UiFont', 'FontFamilyUi', 'Ui')
    }
    foreach ($k in $cands) {
        $r = Find-Res $k
        if ($r -is [System.Windows.Media.FontFamily]) { $script:FontCache[$Kind] = $r; return $r }
    }
    $name = 'Segoe UI'
    if ($Kind -eq 'Mono') { $name = 'Cascadia Mono, Consolas, Courier New' }
    $f = $null
    try { $f = [System.Windows.Media.FontFamily]::new($name) } catch { $f = $null }
    if ($null -ne $f) { $script:FontCache[$Kind] = $f }
    return $f
}

function Get-LevelBrush {
    param([string]$Level)
    # 视觉层专门给了 BrushLogOk / BrushLogWarn / BrushLogErr / BrushLogDim / BrushLogInfo
    # 这组语义色，优先用它们；主题里没有就退回通用语义色。
    $key = 'LogInfo'
    $generic = 'Text'
    $hex = '#E6EDF3'
    switch ($Level) {
        'OK'   { $key = 'LogOk';   $generic = 'Accent2';   $hex = '#10B981' }
        'WARN' { $key = 'LogWarn'; $generic = 'Warn';      $hex = '#F59E0B' }
        'ERR'  { $key = 'LogErr';  $generic = 'Danger';    $hex = '#EF4444' }
        'DIM'  { $key = 'LogDim';  $generic = 'TextFaint'; $hex = '#4A525E' }
        'HEAD' { $key = 'LogInfo'; $generic = 'Accent';    $hex = '#22D3EE' }
        default { $key = 'LogInfo'; $generic = 'Text';     $hex = '#E6EDF3' }
    }
    $r = $null
    try { $r = Find-Res ('Brush' + $key) } catch { $r = $null }
    if ($r -is [System.Windows.Media.Brush]) { return $r }
    return (Get-Brush $generic $hex)
}


# =============================================================================
#  6. XAML 片段规整 + 窗口构建
# =============================================================================

function Normalize-XamlDictionary {
    param([string]$Text)
    $t = ''
    if ($null -ne $Text) { $t = ([string]$Text) }
    $t = $t.Trim().Trim([char]0xFEFF)
    if ($t -eq '' -or $t.StartsWith('<<<')) {
        return '<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" />'
    }
    # 内联进 <Window> 时不允许出现 XML 声明
    $t = [regex]::Replace($t, '(?is)^\s*<\?xml[^>]*\?>\s*', '')
    if ($t -match '<ResourceDictionary[\s>]') { return $t }
    # 裸片段（只给了若干 Storyboard / Style）：包一层，命名空间从父文档继承
    return ("<ResourceDictionary>" + $t + "</ResourceDictionary>")
}

function Normalize-XamlLayout {
    param([string]$Text)
    $t = ''
    if ($null -ne $Text) { $t = ([string]$Text) }
    $t = $t.Trim().Trim([char]0xFEFF)
    if ($t -eq '' -or $t.StartsWith('<<<')) {
        return '<Grid x:Name="RootGrid" />'
    }
    $t = [regex]::Replace($t, '(?is)^\s*<\?xml[^>]*\?>\s*', '')
    return $t
}

function Build-Npc修复网络Window {
    param(
        [string]$ThemeText,
        [string]$AnimText,
        [string]$LayoutText,
        [string]$LangTag
    )

    $themeXaml  = Normalize-XamlDictionary $ThemeText
    $animXaml   = Normalize-XamlDictionary $AnimText
    $layoutXaml = Normalize-XamlLayout    $LayoutText

    # 关键：根标签绝不能用 {StaticResource}。
    # 实测（PS 5.1 / XamlReader.Parse）：根元素的属性在 Window.Resources 填充之前
    # 就被赋值，StaticResource 会抛 "Provide value on StaticResourceExtension threw
    # an exception"。DynamicResource 是延迟解析，可以正常工作；解析完再显式赋一次值
    # 做双保险。
    $windowXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Npc修复网络" Width="780" Height="560"
        MinWidth="720" MinHeight="500"
        WindowStyle="None" AllowsTransparency="False"
        WindowStartupLocation="CenterScreen"
        UseLayoutRounding="True"
        SnapsToDevicePixels="True"
        TextOptions.TextFormattingMode="Display"
        Language="$LangTag"
        Background="{DynamicResource BrushBg}">
  <Window.Resources>
    <ResourceDictionary>
      <ResourceDictionary.MergedDictionaries>
        $themeXaml
        $animXaml
      </ResourceDictionary.MergedDictionaries>
    </ResourceDictionary>
  </Window.Resources>
  $layoutXaml
</Window>
"@

    $w = [Windows.Markup.XamlReader]::Parse($windowXaml)

    # 双保险：解析完再显式把背景钉一次（此时 Resources 一定已填充）
    if ($null -ne $w) {
        $bg = $null
        foreach ($k in @('BrushBg', 'Brush.Bg', 'Brush.ColorBg', 'ColorBg', 'BgBrush')) {
            try { $bg = $w.TryFindResource($k) } catch { $bg = $null }
            if ($null -ne $bg) { break }
        }
        if ($null -eq $bg) { $bg = ConvertTo-Brush '#0B0E13' }
        if ($null -ne $bg) { try { $w.Background = $bg } catch { } }
    }
    return $w
}


# =============================================================================
#  7. 控件注册 / 预置 RenderTransform / 事件挂载
# =============================================================================

$script:CtlNames = @(
    'RootGrid', 'TitleBar', 'TitleText', 'VersionText', 'MinButton', 'CloseButton',
    'RingHost', 'RingTrack', 'RingFill', 'RingPercentText', 'RingGlow',
    'StageText', 'StatusText', 'ProgressBar', 'ProgressGlow', 'DetailText',
    'LogList', 'LogScroll', 'StatusDot', 'StatusLabel', 'StartButton', 'RollbackButton',
    'ParticleLayer', 'GlowLayer', 'PanelMain'
)

function Register-Npc修复网络Controls {
    param([Parameter(Mandatory = $true)]$Win)

    $map = @{}
    $missing = New-Object System.Collections.ArrayList
    foreach ($n in $script:CtlNames) {
        $c = $null
        try { $c = $Win.FindName($n) } catch { $c = $null }
        $map[$n] = $c
        if ($null -eq $c) { [void]$missing.Add($n) }
    }
    $global:GUI = $map
    $global:GUI['L10n'] = $script:L10n
    $global:GUI['Window'] = $Win

    # 视觉层多给了一个日志区标题 LogTitle（不在契约清单里），顺手接管；
    # 不放进 CtlNames 是为了将来它被删掉时不产生"控件缺失"告警。
    $lt = $null
    try { $lt = $Win.FindName('LogTitle') } catch { $lt = $null }
    $global:GUI['LogTitle'] = $lt

    return @($missing)
}

# 动效层不写 TargetName，Storyboard 全靠这里预置的 RenderTransform 才动得起来。
# 少一个 = 对应动画静默失效，不报错，最难查。
function Set-RenderTransformPresets {
    $dot = Get-Ctl 'StatusDot'
    if ($null -ne $dot) {
        try {
            $dot.RenderTransform = [System.Windows.Media.ScaleTransform]::new()
            $dot.RenderTransformOrigin = [System.Windows.Point]::new(0.5, 0.5)
        } catch { }
    }

    $glow = Get-Ctl 'RingGlow'
    if ($null -ne $glow) {
        try {
            $glow.RenderTransform = [System.Windows.Media.RotateTransform]::new()
            $glow.RenderTransformOrigin = [System.Windows.Point]::new(0.5, 0.5)
        } catch { }
    }

    $ringHost = Get-Ctl 'RingHost'
    if ($null -ne $ringHost) {
        try {
            $ringHost.RenderTransform = [System.Windows.Media.ScaleTransform]::new()
            $ringHost.RenderTransformOrigin = [System.Windows.Point]::new(0.5, 0.5)
        } catch { }
    }

    $panel = Get-Ctl 'PanelMain'
    if ($null -ne $panel) {
        try { $panel.RenderTransform = [System.Windows.Media.TranslateTransform]::new() } catch { }
    }

    $pGlow = Get-Ctl 'ProgressGlow'
    if ($null -ne $pGlow) {
        try { $pGlow.RenderTransform = [System.Windows.Media.TranslateTransform]::new() } catch { }
    }

    $particle = Get-Ctl 'ParticleLayer'
    if ($null -ne $particle) {
        try { $particle.RenderTransform = [System.Windows.Media.TranslateTransform]::new() } catch { }
    }
}

function Set-ControlDefaults {
    # 日志列表由宿主自己渲染行，清掉视觉层可能设的 ItemTemplate，
    # 否则我们的 TextBlock 会被模板当成数据对象再 bind 一层。
    $list = Get-Ctl 'LogList'
    if ($null -ne $list) {
        try { $list.ItemTemplate = $null } catch { }
        try { $list.HorizontalContentAlignment = [System.Windows.HorizontalAlignment]::Stretch } catch { }
        try { $list.SelectionMode = [System.Windows.Controls.SelectionMode]::Single } catch { }
        try { $list.IsTabStop = $false } catch { }
    }

    # 进度条统一按 0..100 驱动，防止视觉层给了 0..1 的 Maximum
    $pb = Get-Ctl 'ProgressBar'
    if ($null -ne $pb) {
        try {
            $pb.Minimum = 0
            $pb.Maximum = 100
            $pb.Value = 0
        } catch { }
    }

    # --- StatusDot 必须持有「独享且未冻结」的画刷（Agent B 实测 bug 1）------------
    # 主题里的 BrushXxx 是共享对象，通常已 Freeze：对它做 Color 动画会直接抛异常，
    # 于是 Sb.SuccessFlash 静默失效（看起来像"闪了一下但没颜色变化"）；
    # 而且同一个画刷被 VersionText / DetailText / 日志 OK 行共用，改它等于全场一起变色。
    # Clone() 出来的副本是未冻结的，从此只改这个副本的 Color，不换对象引用。
    $dot = Get-Ctl 'StatusDot'
    if ($null -ne $dot) {
        try {
            if ($null -ne $dot.Fill) { $dot.Fill = $dot.Fill.Clone() }
        } catch { }
        if ($null -eq $dot.Fill) {
            try {
                $b = New-Object System.Windows.Media.SolidColorBrush
                $b.Color = [System.Windows.Media.Color]::FromRgb(0x7D, 0x85, 0x90)
                $dot.Fill = $b
            } catch { }
        }
    }

    # ProgressGlow 的基值是 0，扫光动画跑起来也看不见，先给个可见的不透明度
    $pGlow = Get-Ctl 'ProgressGlow'
    if ($null -ne $pGlow) {
        try {
            if ([double]$pGlow.Opacity -le 0.02) { $pGlow.Opacity = 0.65 }
        } catch { }
    }
}

# 只改 StatusDot 画刷的颜色，绝不替换对象引用（否则会毁掉正在跑的 Color 动画，
# 并且连累所有共用该画刷的控件）。
function Set-DotColorCore {
    param($Color)
    if ($null -eq $Color) { return }
    # 立即改色 = 作废任何还在排队的「延迟定格」，
    # 否则 Success 后 620ms 内切到 Idle，旧定时器会把绿灯盖回来。
    if ($null -ne $script:PendingDotTimer) {
        try { $script:PendingDotTimer.Stop() } catch { }
        $script:PendingDotTimer = $null
    }
    $dot = Get-Ctl 'StatusDot'
    if ($null -eq $dot) { return }
    $brush = $null
    try { $brush = $dot.Fill } catch { $brush = $null }
    if ($null -ne $brush -and $brush -is [System.Windows.Media.SolidColorBrush]) {
        try {
            $brush.Color = $Color
            return
        } catch { }
    }
    # Fill 不是 SolidColorBrush（渐变等）：退化成换一个独享画刷
    try {
        $nb = New-Object System.Windows.Media.SolidColorBrush
        $nb.Color = $Color
        $dot.Fill = $nb
    } catch { }
}

# 延迟定格：Success / Fail 要「先闪、后定格」，否则闪光的起点和终点同色，等于没闪
function Set-DotColorLater {
    param($Color, [int]$DelayMs = 620)
    $script:PendingDotColor = $Color
    if ($null -ne $script:PendingDotTimer) {
        try { $script:PendingDotTimer.Stop() } catch { }
        $script:PendingDotTimer = $null
    }
    try {
        $t = New-Object System.Windows.Threading.DispatcherTimer
        $t.Interval = [TimeSpan]::FromMilliseconds($DelayMs)
        $t.Add_Tick({
            param($sender, $e)
            try { $sender.Stop() } catch { }
            try { Set-DotColorCore $script:PendingDotColor } catch { }
            $script:PendingDotTimer = $null
        })
        $script:PendingDotTimer = $t
        $t.Start()
    } catch {
        Set-DotColorCore $Color
    }
}

function Apply-LocalizedStatic {
    $w = $script:Window
    if ($null -ne $w) {
        try { $w.Title = (T 'App.Title') } catch { }
    }
    $t = Get-Ctl 'TitleText'
    if ($null -ne $t) { try { $t.Text = (T 'App.Title') } catch { } }
    $v = Get-Ctl 'VersionText'
    if ($null -ne $v) { try { $v.Text = (T 'App.Version') } catch { } }
    $p = Get-Ctl 'RingPercentText'
    if ($null -ne $p) { try { $p.Text = '0%' } catch { } }

    # 待机界面必须有内容：整块清空会让小白以为界面坏了。
    # 步骤号给 0/N，说明文字给 Tip.Idle（主控实测反馈第 1 条）。
    $s = Get-Ctl 'StageText'
    if ($null -ne $s) {
        try { $s.Text = (T 'Label.Step' @(0, $script:StageTotal)) } catch { }
    }
    $d = Get-Ctl 'DetailText'
    if ($null -ne $d) {
        try { $d.Text = (T 'Tip.Idle') } catch { }
    }
    $lt = Get-Ctl 'LogTitle'
    if ($null -ne $lt) { try { $lt.Text = (T 'Label.Log') } catch { } }
}

function Attach-UiEvents {
    $w = $script:Window
    if ($null -eq $w) { return }

    $start = Get-Ctl 'StartButton'
    if ($null -ne $start) {
        $start.Add_Click({ Start-RepairRun })
        $start.Add_MouseEnter({
            $script:HoverTarget = Get-Ctl 'StartButton'
            Start-UIAnimation -Key 'Sb.ButtonHover'
            Start-UIAnimation -Key 'Sb.ButtonHoverIn'
        })
        $start.Add_MouseLeave({
            $script:HoverTarget = Get-Ctl 'StartButton'
            Stop-UIAnimation  -Key 'Sb.ButtonHover'
            Start-UIAnimation -Key 'Sb.ButtonHoverOut'
        })
    }

    $roll = Get-Ctl 'RollbackButton'
    if ($null -ne $roll) {
        $roll.Add_Click({ Start-RollbackRun })
        $roll.Add_MouseEnter({
            $script:HoverTarget = Get-Ctl 'RollbackButton'
            Start-UIAnimation -Key 'Sb.ButtonHover'
            Start-UIAnimation -Key 'Sb.ButtonHoverIn'
        })
        $roll.Add_MouseLeave({
            $script:HoverTarget = Get-Ctl 'RollbackButton'
            Stop-UIAnimation  -Key 'Sb.ButtonHover'
            Start-UIAnimation -Key 'Sb.ButtonHoverOut'
        })
    }

    $close = Get-Ctl 'CloseButton'
    if ($null -ne $close) { $close.Add_Click({ if ($null -ne $script:Window) { $script:Window.Close() } }) }

    $min = Get-Ctl 'MinButton'
    if ($null -ne $min) {
        $min.Add_Click({ if ($null -ne $script:Window) { $script:Window.WindowState = [System.Windows.WindowState]::Minimized } })
    }

    $bar = Get-Ctl 'TitleBar'
    if ($null -ne $bar) {
        $bar.Add_MouseLeftButtonDown({
            try { if ($null -ne $script:Window) { $script:Window.DragMove() } } catch { }
        })
    }

    $w.Add_Closing({
        param($sender, $e)
        if ($script:Running) {
            $r = [System.Windows.MessageBoxResult]::No
            try {
                $r = [System.Windows.MessageBox]::Show($script:Window, (T 'Ask.QuitRunning'), (T 'Ask.Title'),
                    [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
            } catch { $r = [System.Windows.MessageBoxResult]::Yes }
            if ($r -ne [System.Windows.MessageBoxResult]::Yes) {
                $e.Cancel = $true
                return
            }
            Stop-BackgroundRun
        }
    })

    $w.Add_Closed({
        try { Stop-FlushTimer } catch { }
        try { Stop-AllAnimations } catch { }
        try { Stop-BackgroundRun } catch { }
        try { $script:UiQueue = $null } catch { }
    })
}


# =============================================================================
#  8. Storyboard 控制
# =============================================================================
#  动效层的 Storyboard 不带 TargetName，必须在 Clone 出来的副本上 SetTarget，
#  否则同一个 Storyboard 实例既不能同时挂两个目标，也不能重复 Begin。

#  Key -> 目标控件名。'@hover' / '@logrow' 是动态目标，见 HOST.md §5。
function Get-AnimationTargetName {
    param([string]$Key)
    switch ($Key) {
        'Sb.IdlePulse'         { return 'StatusDot' }
        'Sb.RingSpin'          { return 'RingGlow' }
        'Sb.RunningBreath'     { return 'RingGlow' }
        'Sb.PanelFadeIn'       { return 'PanelMain' }
        'Sb.SuccessFlash'      { return 'StatusDot' }
        'Sb.FailFlash'         { return 'StatusDot' }
        'Sb.ProgressGlowSweep' { return 'ProgressGlow' }
        'Sb.RingSettle'        { return 'RingHost' }
        'Sb.ParticleDrift'     { return 'ParticleLayer' }
        default                { return $null }
    }
}

# 核心：从资源拿 Storyboard -> Clone -> SetTarget -> Begin。
# 找不到资源就静默返回（动效层可能还没交 Key），绝不打断修复流程。
function Invoke-StoryboardOn {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        $Element
    )
    if ($null -eq $script:Window) { return $false }
    $base = $null
    try { $base = $script:Window.TryFindResource($Key) } catch { $base = $null }
    if ($null -eq $base) { return $false }
    if (-not ($base -is [System.Windows.Media.Animation.Storyboard])) { return $false }

    $sb = $null
    try { $sb = $base.Clone() } catch { return $false }
    if ($null -eq $sb) { return $false }

    if ($null -ne $Element) {
        try { [System.Windows.Media.Animation.Storyboard]::SetTarget($sb, $Element) } catch { }
    }
    try { $sb.Begin() } catch { return $false }

    if (-not $script:ActiveStoryboards.ContainsKey($Key)) {
        $script:ActiveStoryboards[$Key] = New-Object System.Collections.ArrayList
    }
    [void]$script:ActiveStoryboards[$Key].Add($sb)
    return $true
}

function Start-UIAnimation {
    param([Parameter(Mandatory = $true)][string]$Key)

    if ([string]::IsNullOrWhiteSpace($Key)) { return }
    if (-not (Test-OnUiThread)) {
        Push-UiEvent @{ Kind = 'AnimStart'; Key = $Key }
        return
    }

    # 同名动画先停，避免 hover 这种高频触发把 Storyboard 堆成山
    Stop-UIAnimation -Key $Key

    $target = $null
    if ($Key -eq 'Sb.ButtonHover' -or $Key -eq 'Sb.ButtonHoverIn' -or $Key -eq 'Sb.ButtonHoverOut') {
        $target = $script:HoverTarget
    } else {
        $name = Get-AnimationTargetName $Key
        if ($null -ne $name) { $target = Get-Ctl $name }
    }

    [void](Invoke-StoryboardOn -Key $Key -Element $target)
}

function Stop-UIAnimation {
    param([Parameter(Mandatory = $true)][string]$Key)

    if ([string]::IsNullOrWhiteSpace($Key)) { return }
    if (-not (Test-OnUiThread)) {
        Push-UiEvent @{ Kind = 'AnimStop'; Key = $Key }
        return
    }
    if (-not $script:ActiveStoryboards.ContainsKey($Key)) { return }
    $list = $script:ActiveStoryboards[$Key]
    if ($null -ne $list) {
        foreach ($sb in @($list)) {
            try { $sb.Stop() } catch { }
        }
    }
    $script:ActiveStoryboards.Remove($Key)
}

function Stop-AllAnimations {
    $keys = @()
    try { $keys = @($script:ActiveStoryboards.Keys) } catch { $keys = @() }
    foreach ($k in $keys) {
        try { Stop-UIAnimation -Key ([string]$k) } catch { }
    }
    $script:ActiveStoryboards = @{}
}


# =============================================================================
#  9. 环形进度（Ellipse / Path 双兼容）
# =============================================================================

function Get-RingGeometryLength {
    param($El)
    if ($null -eq $El) { return 0.0 }

    $geo = $null
    try {
        if ($El -is [System.Windows.Shapes.Path]) { $geo = $El.Data }
        elseif ($El -is [System.Windows.Shapes.Shape]) { $geo = $El.RenderedGeometry }
    } catch { $geo = $null }

    if ($null -ne $geo) {
        $len = 0.0
        try {
            if (-not $geo.IsEmpty()) {
                $flat = $geo.GetFlattenedPathGeometry()
                foreach ($fig in $flat.Figures) {
                    $cur = $fig.StartPoint
                    foreach ($seg in $fig.Segments) {
                        if ($seg -is [System.Windows.Media.PolyLineSegment]) {
                            foreach ($pt in $seg.Points) {
                                $len += ([double](($pt - $cur).Length))
                                $cur = $pt
                            }
                        } elseif ($seg -is [System.Windows.Media.LineSegment]) {
                            $len += ([double](($seg.Point - $cur).Length))
                            $cur = $seg.Point
                        }
                    }
                }
            }
        } catch { $len = 0.0 }
        if ($len -gt 0.5) { return $len }
    }

    # 兜底：椭圆周长（Ramanujan 近似）
    if ($El -is [System.Windows.Shapes.Ellipse]) {
        $w = 0.0; $h = 0.0
        try { $w = [double]$El.Width } catch { $w = 0 }
        try { $h = [double]$El.Height } catch { $h = 0 }
        if ($w -le 0) { try { $w = [double]$El.ActualWidth } catch { $w = 0 } }
        if ($h -le 0) { try { $h = [double]$El.ActualHeight } catch { $h = 0 } }
        if ($w -gt 0 -and $h -gt 0) {
            $a = $w / 2.0
            $b = $h / 2.0
            return ([math]::PI * (3.0 * ($a + $b) - [math]::Sqrt((3.0 * $a + $b) * ($a + 3.0 * $b))))
        }
    }
    return 0.0
}

# 原理：把 StrokeDashArray 设成 [N, N]（N = 周长 / 描边宽），
# 这样「一段实线 + 一段空白」正好绕整圈一遍。StrokeDashOffset 从 0 走到 N，
# 可见弧长就从 100% 缩到 0%，且 StrokeDashOffset 是 Double 可动画的属性，
# 能用 260ms CubicEase 平滑补间（DoubleCollection 本身不可动画）。
function Set-RingCore {
    param([double]$Percent)

    if ($Percent -lt 0) { $Percent = 0 }
    if ($Percent -gt 100) { $Percent = 100 }

    $txt = Get-Ctl 'RingPercentText'
    if ($null -ne $txt) {
        try { $txt.Text = ('{0}%' -f [int][math]::Round($Percent)) } catch { }
    }

    $el = Get-Ctl 'RingFill'
    if ($null -eq $el) { return }

    if ($script:RingLength -le 0) { $script:RingLength = Get-RingGeometryLength $el }
    $len = [double]$script:RingLength
    if ($len -le 0.5) { return }

    $th = 1.0
    try { if ([double]$el.StrokeThickness -gt 0) { $th = [double]$el.StrokeThickness } } catch { $th = 1.0 }
    $n = $len / $th
    if ($n -le 0) { return }

    if (-not $script:RingDashReady) { $script:RingDashReady = $true }

    # 周长/描边宽变了要重算 dash 单位，所以每次都重建（构造一个 2 元素集合很便宜）
    try {
        $dc = New-Object System.Windows.Media.DoubleCollection
        $dc.Add($n)
        $dc.Add($n)
        $el.StrokeDashArray = $dc
    } catch { }

    $from = 0.0
    try { $from = [double]$el.StrokeDashOffset } catch { $from = 0.0 }
    $to = $n * (1.0 - ($Percent / 100.0))

    # 0% 时 dash 长度趋零，但 Round 端帽照样画出一个点，会在 12 点方向留个小圆球。
    # 视觉层 DESIGN.md 的约定：p <= 0.001 直接把 RingFill 透明掉（主控实测反馈第 2 条）。
    try {
        if ($Percent -le 0.001) { $el.Opacity = 0.0 } else { $el.Opacity = 1.0 }
    } catch { }

    try {
        if ($el -is [System.Windows.Shapes.Shape]) {
            if (-not $script:RingTweenEnabled) {
                # 瞬切模式：与视觉层 DESIGN.md 的「dash 写死 + 不做动画」等价，
                # 先把动画时钟摘掉，否则残留动画会盖住静态赋值。
                try { $el.BeginAnimation([System.Windows.Shapes.Shape]::StrokeDashOffsetProperty, $null) } catch { }
                $el.StrokeDashOffset = $to
                return
            }
            # 先把基准值落到目标，动画用 FillBehavior=Stop 收尾时自然停在目标值
            $el.StrokeDashOffset = $to

            $anim = New-Object System.Windows.Media.Animation.DoubleAnimation
            $anim.From = $from
            $anim.To = $to
            $anim.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds($script:RingAnimMs))
            $anim.FillBehavior = [System.Windows.Media.Animation.FillBehavior]::Stop
            $ease = New-Object System.Windows.Media.Animation.CubicEase
            $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
            $anim.EasingFunction = $ease
            # BeginAnimation 默认 SnapshotAndReplace：新的动画直接替换旧的，
            # 不会叠加，所以连续 Update-Progress 不会累积误差。
            $el.BeginAnimation([System.Windows.Shapes.Shape]::StrokeDashOffsetProperty, $anim)
        }
    } catch {
        try { $el.StrokeDashOffset = $to } catch { }
    }
}

function Update-Ring {
    param([Parameter(Mandatory = $true)][int]$Percent)
    if (-not (Test-OnUiThread)) {
        Push-UiEvent @{ Kind = 'Progress'; Percent = $Percent }
        return
    }
    Set-RingCore -Percent $Percent
}


# =============================================================================
#  10. 日志渲染
# =============================================================================

function Add-LogRow {
    param(
        [string]$Level = 'INFO',
        [Parameter(Mandatory = $true)][string]$Text
    )
    $list = Get-Ctl 'LogList'
    if ($null -eq $list) { return $null }

    $body = [string]$Text
    if ($body.Length -gt $script:MaxRawLine) { $body = $body.Substring(0, $script:MaxRawLine) + '...' }

    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = ('[' + (Get-Date -Format 'HH:mm:ss') + '] ' + $body)
    $mono = Get-UiFont 'Mono'
    if ($null -ne $mono) { $tb.FontFamily = $mono }
    $tb.FontSize = 12
    $tb.TextWrapping = [System.Windows.TextWrapping]::NoWrap
    $tb.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    $tb.Margin = [System.Windows.Thickness]::new(0, 1, 4, 1)
    $tb.Tag = $Level
    $br = Get-LevelBrush $Level
    if ($null -ne $br) { $tb.Foreground = $br }

    try {
        [void]$list.Items.Add($tb)
    } catch { return $null }

    try {
        $guard = 0
        while ($list.Items.Count -gt $script:LogLimit -and $guard -lt 400) {
            $list.Items.RemoveAt(0)
            $guard++
        }
    } catch { }
    return $tb
}

function Clear-LogList {
    $list = Get-Ctl 'LogList'
    if ($null -eq $list) { return }
    try { $list.Items.Clear() } catch { }
}

function Scroll-LogToEnd {
    $list = Get-Ctl 'LogList'
    if ($null -ne $list) {
        try {
            if ($list.Items.Count -gt 0) { $list.ScrollIntoView($list.Items[$list.Items.Count - 1]) }
        } catch { }
    }
    $sv = Get-Ctl 'LogScroll'
    if ($null -ne $sv) {
        try { $sv.ScrollToEnd() } catch { }
    }
}


# =============================================================================
#  11. UI 更新接口（8 个冻结函数里的 5 个）
# =============================================================================
#  都能被后台线程直接调：不在 UI 线程就自动丢进队列，由定时器统一渲染。

function Update-Stage {
    param(
        [Parameter(Mandatory = $true)][int]$Index,
        [Parameter(Mandatory = $true)][int]$Total,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if (-not (Test-OnUiThread)) {
        Push-UiEvent @{ Kind = 'Stage'; Index = $Index; Total = $Total; Name = $Name }
        return
    }
    $st = Get-Ctl 'StageText'
    if ($null -ne $st) { try { $st.Text = (T 'Label.Step' @($Index, $Total)) } catch { } }
    $sn = Get-Ctl 'StatusText'
    if ($null -ne $sn -and -not [string]::IsNullOrWhiteSpace($Name)) {
        try { $sn.Text = $Name } catch { }
    }
}

function Update-Log {
    param(
        [string]$Level = 'INFO',
        [Parameter(Mandatory = $true)][string]$Text
    )
    if (-not (Test-OnUiThread)) {
        Push-UiEvent @{ Kind = 'Log'; Level = $Level; Text = $Text }
        return
    }
    $lv = 'INFO'
    switch (([string]$Level).ToUpper()) {
        'OK'   { $lv = 'OK' }
        'WARN' { $lv = 'WARN' }
        'ERR'  { $lv = 'ERR' }
        'DIM'  { $lv = 'DIM' }
        'HEAD' { $lv = 'HEAD' }
        default { $lv = 'INFO' }
    }
    [void](Add-LogRow -Level $lv -Text $Text)
    Scroll-LogToEnd
}

function Update-Progress {
    param([Parameter(Mandatory = $true)][int]$Percent)
    if (-not (Test-OnUiThread)) {
        Push-UiEvent @{ Kind = 'Progress'; Percent = $Percent }
        return
    }
    if ($Percent -lt 0) { $Percent = 0 }
    if ($Percent -gt 100) { $Percent = 100 }
    $pb = Get-Ctl 'ProgressBar'
    if ($null -ne $pb) { try { $pb.Value = $Percent } catch { } }
    Set-RingCore -Percent $Percent
}

function Update-Detail {
    param([string]$Text = '')
    if (-not (Test-OnUiThread)) {
        Push-UiEvent @{ Kind = 'Detail'; Text = $Text }
        return
    }
    $d = Get-Ctl 'DetailText'
    if ($null -eq $d) { return }
    $t = [string]$Text
    if ($t.Length -gt 110) { $t = $t.Substring(0, 110) + '...' }
    try { $d.Text = $t } catch { }
}

function Set-UIState {
    param([ValidateSet('Idle', 'Running', 'Success', 'Warn', 'Fail')][string]$State = 'Idle')

    if (-not (Test-OnUiThread)) {
        Push-UiEvent @{ Kind = 'State'; Value = $State }
        return
    }
    $script:CurrentState = $State

    $dotName = 'TextFaint'
    $dotHex = '#7D8590'
    switch ($State) {
        'Running' { $dotName = 'Accent';  $dotHex = '#22D3EE' }
        'Success' { $dotName = 'Accent2'; $dotHex = '#10B981' }
        'Warn'    { $dotName = 'Warn';    $dotHex = '#F59E0B' }
        'Fail'    { $dotName = 'Danger';  $dotHex = '#EF4444' }
        default   { $dotName = 'TextFaint'; $dotHex = '#7D8590' }
    }

    # 解析目标颜色（只取 Color 值，绝不把主题里的共享画刷对象挂到控件上）
    $dotColor = $null
    $srcBrush = Get-Brush $dotName $dotHex
    if ($null -ne $srcBrush) {
        try { $dotColor = $srcBrush.Color } catch { $dotColor = $null }
    }
    if ($null -eq $dotColor) {
        $fb = ConvertTo-Brush $dotHex
        if ($null -ne $fb) { try { $dotColor = $fb.Color } catch { } }
    }

    $label = Get-Ctl 'StatusLabel'
    if ($null -ne $label) { try { $label.Text = (T ('State.' + $State)) } catch { } }

    $status = Get-Ctl 'StatusText'
    if ($null -ne $status -and $State -ne 'Running') {
        try { $status.Text = (T ('State.' + $State)) } catch { }
    }

    $start = Get-Ctl 'StartButton'
    if ($null -ne $start) {
        try {
            $start.IsEnabled = ($State -ne 'Running') -and (-not $script:NoAdmin)
            if ($State -eq 'Running') { $start.Content = (T 'Btn.Running') }
            elseif ($State -eq 'Idle') { $start.Content = (T 'Btn.Start') }
            else { $start.Content = (T 'Btn.Retry') }
        } catch { }
    }

    $roll = Get-Ctl 'RollbackButton'
    if ($null -ne $roll) {
        try {
            $canRoll = ($State -ne 'Running') -and (-not $script:NoAdmin) -and (Test-HasBackup)
            $roll.IsEnabled = $canRoll
        } catch { }
    }

    # 先起动画，再定格颜色。
    # Success / Fail 的 flash 是从「当前色」出发的，如果先改颜色，起点终点同色 = 看不见；
    # 所以这两个状态延后 620ms 再定格，其余状态立即改色。
    $isFlash = ($State -eq 'Success' -or $State -eq 'Fail')

    # 状态机清理：先把「上一个状态拥有」的动画全停掉，再按新状态起。
    # 不这么做的话，Success 的 flash 会一直留在 ActiveStoryboards 里跟着跑到 Fail。
    foreach ($k in @('Sb.IdlePulse', 'Sb.RingSpin', 'Sb.RunningBreath', 'Sb.ProgressGlowSweep', 'Sb.SuccessFlash', 'Sb.FailFlash')) {
        Stop-UIAnimation -Key $k
    }
    switch ($State) {
        'Idle'    { Start-UIAnimation -Key 'Sb.IdlePulse' }
        'Running' {
            Start-UIAnimation -Key 'Sb.RingSpin'
            Start-UIAnimation -Key 'Sb.RunningBreath'
            Start-UIAnimation -Key 'Sb.ProgressGlowSweep'
        }
        'Success' { Start-UIAnimation -Key 'Sb.SuccessFlash' }
        'Warn'    { Start-UIAnimation -Key 'Sb.IdlePulse' }
        'Fail'    { Start-UIAnimation -Key 'Sb.FailFlash' }
    }

    if ($null -ne $dotColor) {
        if ($isFlash) { Set-DotColorLater -Color $dotColor -DelayMs 620 }
        else { Set-DotColorCore $dotColor }
    }
}


# =============================================================================
#  12. 线程判定 / 队列
# =============================================================================

function Test-OnUiThread {
    if ($script:UiThreadId -le 0) { return $true }
    try { return ([System.Threading.Thread]::CurrentThread.ManagedThreadId -eq $script:UiThreadId) } catch { return $true }
}

function Push-UiEvent {
    param([hashtable]$Event)
    if ($null -eq $script:UiQueue) { return }
    try { $script:UiQueue.Enqueue($Event) } catch { }
}

function Initialize-UiPipeline {
    $script:UiThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    $script:UiQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
}

function Start-FlushTimer {
    Stop-FlushTimer
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds($script:FlushInterval)
    $timer.Add_Tick({ Flush-UiQueue })
    $script:RefreshTimer = $timer
    $timer.Start()
}

function Stop-FlushTimer {
    if ($null -eq $script:RefreshTimer) { return }
    try { $script:RefreshTimer.Stop() } catch { }
    $script:RefreshTimer = $null
}

# 队列 + 100ms 批量刷新：后台一秒几十条日志也不会把 UI 线程抢爆。
function Flush-UiQueue {
    if ($null -eq $script:UiQueue) { return }

    $batch = 0
    $lastRow = $null
    $needScroll = $false
    $item = $null

    while ($batch -lt $script:FlushBatch) {
        $got = $false
        try { $got = $script:UiQueue.TryDequeue([ref]$item) } catch { $got = $false }
        if (-not $got) { break }
        $batch++
        if ($null -eq $item) { continue }

        $kind = ''
        try { $kind = [string]$item['Kind'] } catch { $kind = '' }

        switch ($kind) {
            'Log' {
                $lv = 'INFO'
                if ($item.ContainsKey('Level')) { $lv = [string]$item['Level'] }
                $text = $null
                if ($item.ContainsKey('Text')) {
                    $text = [string]$item['Text']
                } elseif ($item.ContainsKey('Code')) {
                    $code = [string]$item['Code']
                    if ($item.ContainsKey('Arg')) { $text = (T $code @([string]$item['Arg'])) }
                    else { $text = (T $code) }
                }
                if ([string]::IsNullOrWhiteSpace($text)) { continue }
                $row = Add-LogRow -Level $lv -Text $text
                if ($null -ne $row) { $lastRow = $row }
                $needScroll = $true
                Update-Detail -Text $text
            }
            'Raw' {
                if (-not $item.ContainsKey('Text')) { continue }
                $text = [string]$item['Text']
                if ([string]::IsNullOrWhiteSpace($text)) { continue }
                [void](Add-LogRow -Level 'DIM' -Text $text)
                $needScroll = $true
            }
            'Stage' {
                $idx = 1; $tot = 1; $key = ''
                if ($item.ContainsKey('Index')) { $idx = [int]$item['Index'] }
                if ($item.ContainsKey('Total')) { $tot = [int]$item['Total'] }
                if ($item.ContainsKey('Key')) { $key = [string]$item['Key'] }
                $nm = $key
                if (-not [string]::IsNullOrWhiteSpace($key)) { $nm = (T $key) }
                Update-Stage -Index $idx -Total $tot -Name $nm
                if (-not [string]::IsNullOrWhiteSpace($nm)) {
                    [void](Add-LogRow -Level 'HEAD' -Text ('--- ' + $nm + ' ---'))
                    $needScroll = $true
                }
            }
            'Progress' {
                if ($item.ContainsKey('Percent')) { Update-Progress -Percent ([int]$item['Percent']) }
            }
            'Detail' {
                if ($item.ContainsKey('Text')) { Update-Detail -Text ([string]$item['Text']) }
            }
            'State' {
                if ($item.ContainsKey('Value')) {
                    $v = [string]$item['Value']
                    if (@('Idle', 'Running', 'Success', 'Warn', 'Fail') -contains $v) { Set-UIState -State $v }
                }
            }
            'AnimStart' {
                if ($item.ContainsKey('Key')) { Start-UIAnimation -Key ([string]$item['Key']) }
            }
            'AnimStop' {
                if ($item.ContainsKey('Key')) { Stop-UIAnimation -Key ([string]$item['Key']) }
            }
            'Done' {
                Complete-UiRun -Item $item
            }
            default { }
        }
    }

    if ($needScroll) { Scroll-LogToEnd }
    if ($null -ne $lastRow) {
        [void](Invoke-StoryboardOn -Key 'Sb.LogRowIn' -Element $lastRow)
    }
}

# 一轮后台任务收尾：只做 UI 收尾，不碰 runspace（留给下一次 Start / 窗口关闭回收）
function Complete-UiRun {
    param([hashtable]$Item)

    $script:Running = $false

    $state = 'Fail'
    if ($Item.ContainsKey('State')) { $state = [string]$Item['State'] }
    if (@('Idle', 'Running', 'Success', 'Warn', 'Fail') -notcontains $state) { $state = 'Fail' }

    $pass = 0; $tot = 0
    if ($Item.ContainsKey('Pass')) { $pass = [int]$Item['Pass'] }
    if ($Item.ContainsKey('Total')) { $tot = [int]$Item['Total'] }
    if ($tot -gt 0) {
        [void](Add-LogRow -Level 'INFO' -Text (T 'Log.Verify' @($pass, $tot)))
    }

    $ok = 0; $fail = 0; $skip = 0; $secs = 0
    if ($Item.ContainsKey('OK')) { $ok = [int]$Item['OK'] }
    if ($Item.ContainsKey('Fail')) { $fail = [int]$Item['Fail'] }
    if ($Item.ContainsKey('Skip')) { $skip = [int]$Item['Skip'] }
    if ($Item.ContainsKey('Seconds')) { $secs = [int]$Item['Seconds'] }
    [void](Add-LogRow -Level 'INFO' -Text (T 'Log.Summary' @($ok, $fail, $skip, $secs)))

    if ($state -eq 'Success') {
        Update-Progress -Percent 100
        # 环形「落定」一下，给成功一个收尾手感（RingHost 上的 ScaleTransform）
        Start-UIAnimation -Key 'Sb.RingSettle'
    }
    Set-UIState -State $state
    Scroll-LogToEnd
}


# =============================================================================
#  13. 主引擎源码定位与裁剪
# =============================================================================
#  主引擎是一个「顶层有 param() + 末尾直接跑主流程」的脚本，不能 dot-source
#  （一 source 就把界面卡死并开始改系统设置）。所以这里做两刀外科手术：
#    A. 砍掉文件头 <# 说明 #> 与 param(...) 块
#    B. 从顶层第一句 Initialize-Log 处截断，丢掉整个主流程
#  剩下的就是「纯函数库」，丢进后台 Runspace 执行定义，再由宿主按阶段调用。

function Read-TextFileSmart {
    param([Parameter(Mandatory = $true)][string]$Path)
    $bytes = [IO.File]::ReadAllBytes($Path)
    $utf8 = [Text.Encoding]::UTF8
    $txt = $utf8.GetString($bytes)
    if ($txt.IndexOf([char]0xFFFD) -ge 0) {
        # UTF-8 解出替换符 -> 多半是 ANSI/GBK 编码，退回系统默认代码页
        try { $txt = [Text.Encoding]::Default.GetString($bytes) } catch { }
    }
    if ($txt.Length -gt 0 -and $txt[0] -eq [char]0xFEFF) { $txt = $txt.Substring(1) }
    return $txt
}

function Get-EngineSourceText {
    # 1) 主控内联优先
    $inline = $script:EngineInlineText
    if (-not [string]::IsNullOrWhiteSpace($inline) -and -not $inline.Trim().StartsWith('<<<')) {
        return $inline
    }

    # 2) 磁盘同目录
    $cands = New-Object System.Collections.ArrayList
    if (-not [string]::IsNullOrWhiteSpace($script:EnginePath)) { [void]$cands.Add($script:EnginePath) }
    $roots = New-Object System.Collections.ArrayList
    try { if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { [void]$roots.Add($PSScriptRoot) } } catch { }
    try { if (-not [string]::IsNullOrWhiteSpace($script:SelfPath)) { [void]$roots.Add((Split-Path -Parent $script:SelfPath)) } } catch { }
    try { [void]$roots.Add((Get-Location).Path) } catch { }
    foreach ($r in $roots) {
        if ([string]::IsNullOrWhiteSpace($r)) { continue }
        [void]$cands.Add((Join-Path $r 'Npc修复网络.ps1'))
        [void]$cands.Add((Join-Path $r 'NpcNetRepair.ps1'))
        [void]$cands.Add((Join-Path $r 'Npc修复网络-Engine.ps1'))
        try { [void]$cands.Add((Join-Path (Split-Path -Parent $r) 'Npc修复网络.ps1')) } catch { }
    }

    foreach ($p in $cands) {
        try {
            if (Test-Path -LiteralPath $p) { return (Read-TextFileSmart -Path $p) }
        } catch { }
    }
    return ''
}

function Get-EngineCallableSource {
    param([string]$Text = '')

    if ([string]::IsNullOrWhiteSpace($Text)) { throw 'ENGINE_EMPTY' }

    $t = $Text -replace "`r`n", "`n"

    # --- A1: 砍文件头 <# ... #>（只砍开头那一块） ---
    $head = $t.TrimStart()
    if ($head.StartsWith('<#')) {
        $end = $t.IndexOf('#>')
        if ($end -gt 0) { $t = $t.Substring($end + 2) }
    }

    # --- A2: 砍 param(...) 块（含可选的 [CmdletBinding()]） ---
    $cut = -1
    $m = [regex]::Match($t, '(?m)^[ \t]*\[CmdletBinding\(\)\][ \t]*$')
    if ($m.Success) { $cut = $m.Index + $m.Length }
    else {
        $m2 = [regex]::Match($t, '(?m)^[ \t]*param[ \t]*\(')
        if ($m2.Success) { $cut = $m2.Index }
    }
    if ($cut -ge 0) {
        $tail = $t.Substring($cut)
        $openRel = $tail.IndexOf('(')
        if ($openRel -ge 0) {
            $limit = [math]::Min($tail.Length, $openRel + 4000)
            $depth = 0
            $closeRel = -1
            for ($i = $openRel; $i -lt $limit; $i++) {
                $ch = $tail[$i]
                if ($ch -eq [char]'(') { $depth++ }
                elseif ($ch -eq [char]')') {
                    $depth--
                    if ($depth -eq 0) { $closeRel = $i; break }
                }
            }
            if ($closeRel -gt 0) { $t = $tail.Substring($closeRel + 1) }
            else { $t = $tail }
        }
    }

    # --- B: 从顶层 Initialize-Log 处截断，丢掉主流程 ---
    $lines = $t -split "`n"
    $stop = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^Initialize-Log[ \t]*$') { $stop = $i; break }
    }
    if ($stop -lt 0) {
        # 备用锚点：主流程注释横幅
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^[ \t]*#[ \t]*=+[ \t]*$' -and ($i + 2) -lt $lines.Count -and $lines[$i + 1] -match '主流程') {
                $stop = $i
                break
            }
        }
    }
    if ($stop -eq 0) { return '' }
    if ($stop -gt 0) { $lines = $lines[0..($stop - 1)] }

    $out = ($lines -join "`n")
    # 保险丝：万一 exit / Read-Host 漏进函数区，直接删掉
    $out = [regex]::Replace($out, '(?m)^[ \t]*exit\b[^\n]*$', '')
    return $out
}


# =============================================================================
#  14. 后台执行体（跑在独立 STA Runspace 里）
# =============================================================================
#  这里只做三件事：加载引擎函数 -> 按阶段调用 -> 把事件塞进队列。
#  绝不对 WPF 对象下手（跨线程碰 DependencyObject 会直接炸）。

$script:WorkerBody = {
    param(
        $Queue,
        [string]$EngineSource,
        [string]$Mode,
        [bool]$Deep,
        [int]$TotalSteps = 11
    )

    $ErrorActionPreference = 'Continue'
    $ProgressPreference    = 'SilentlyContinue'
    $WarningPreference     = 'SilentlyContinue'

    $script:NRBase = 0.0
    $script:NRSpan = 100.0
    $script:NRFrac = 0.0
    $script:NRLoaded = $false

    function Push-NR {
        param([hashtable]$E)
        try { $Queue.Enqueue($E) } catch { }
    }

    function Set-NRStage {
        param([int]$Index, [int]$Total, [string]$Key)
        if ($Total -lt 1) { $Total = 1 }
        $script:NRBase = (($Index - 1) * 100.0) / [double]$Total
        $script:NRSpan = 100.0 / [double]$Total
        $script:NRFrac = 0.0
        Push-NR @{ Kind = 'Stage'; Index = $Index; Total = $Total; Key = $Key }
        Push-NR @{ Kind = 'Progress'; Percent = [int][math]::Floor($script:NRBase) }
    }

    function Send-Log {
        param([string]$Level, [string]$Text)
        Push-NR @{ Kind = 'Log'; Level = $Level; Text = $Text }
        if ($Level -eq 'OK' -or $Level -eq 'ERR') {
            $script:NRFrac = [math]::Min(0.92, $script:NRFrac + 0.085)
            $p = [int][math]::Floor($script:NRBase + $script:NRSpan * $script:NRFrac)
            if ($p -gt 99) { $p = 99 }
            Push-NR @{ Kind = 'Progress'; Percent = $p }
        }
    }

    # --- 接管引擎的三个输出函数 ---------------------------------------------
    # Write-Host：引擎里所有散装输出（验证表格等）转成原始文本行
    function Write-Host {
        [CmdletBinding()]
        param(
            [Parameter(Position = 0, ValueFromPipeline = $true)]$Object,
            [switch]$NoNewline,
            [object]$ForegroundColor,
            [object]$BackgroundColor,
            [switch]$Separator
        )
        process {
            if ($null -eq $Object) { return }
            $txt = ''
            try { $txt = [string]$Object } catch { return }
            if ($txt -eq '') { return }
            foreach ($ln in ($txt -split "`r?`n")) {
                $s = ([string]$ln).TrimEnd()
                if ($s.Trim() -eq '') { continue }
                Push-NR @{ Kind = 'Raw'; Text = $s }
            }
        }
    }

    # Write-Log：保留磁盘日志，同时把结构化行推给 UI
    function Write-Log {
        param(
            [Parameter(Position = 0)][string]$Msg = '',
            [Parameter(Position = 1)][string]$Level = 'INFO'
        )
        $ts = Get-Date -Format 'HH:mm:ss'
        $line = '[' + $ts + '][' + $Level + '] ' + $Msg
        try { Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch { }
        Send-Log $Level $Msg
    }

    # Write-Head：阶段标题由 UI 用本地化文案自己画，这里只落盘
    function Write-Head {
        param([string]$Text)
        try {
            Add-Content -LiteralPath $script:LogFile -Value '' -Encoding UTF8 -ErrorAction SilentlyContinue
            Add-Content -LiteralPath $script:LogFile -Value ('===== ' + $Text + ' =====') -Encoding UTF8 -ErrorAction SilentlyContinue
        } catch { }
    }

    # --- 引擎函数库载入 ------------------------------------------------------
    try {
        if ([string]::IsNullOrWhiteSpace($EngineSource)) { throw 'ENGINE_SOURCE_EMPTY' }
        Invoke-Expression $EngineSource
        $script:NRLoaded = $true
    } catch {
        Push-NR @{ Kind = 'Log'; Level = 'ERR'; Code = 'Err.EngineLoad'; Arg = $_.Exception.Message }
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $finalState = 'Fail'
    $verify = $null
    $passCount = 0
    $verifyTotal = 0

    try {
        if ($script:NRLoaded) {
            # 主流程里原本负责初始化的几行，必须由宿主补上，否则引擎会降级运行
            try { Initialize-Log } catch { }
            try { $script:HasNetCmdlet = Test-NetCmdlet } catch { $script:HasNetCmdlet = $false }
            try { $script:IsRemote = Test-IsRemoteSession } catch { $script:IsRemote = $false }

            # 引擎的开关变量是动态作用域读取的，这里显式钉死，避免环境串味
            $DryRun = $false
            $ForceDhcp = $false
            $KeepStaticIP = $false
            $SkipAdapterReload = $false
            $RestoreHosts = $false
            $RestoreConfig = $false
            $NoPause = $true
            $Yes = $true

            if ($Mode -eq 'Rollback') {
                $total = 2
                Set-NRStage 1 $total 'Stage.RollbackHosts'
                try { Invoke-RestoreHosts } catch { Push-NR @{ Kind = 'Log'; Level = 'ERR'; Code = 'Err.StageCrash'; Arg = 'Invoke-RestoreHosts' } }
                Set-NRStage 2 $total 'Stage.RollbackConfig'
                try { Invoke-RestoreConfig } catch { Push-NR @{ Kind = 'Log'; Level = 'ERR'; Code = 'Err.StageCrash'; Arg = 'Invoke-RestoreConfig' } }
                Push-NR @{ Kind = 'Progress'; Percent = 100 }

                $f = 0
                try { if ($null -ne $script:FailCount) { $f = [int]$script:FailCount } } catch { }
                if ($f -gt 0) { $finalState = 'Warn' } else { $finalState = 'Success' }
            } else {
                $total = $TotalSteps
                if ($total -lt 2) { $total = 11 }
                $stages = @(
                    @{ Key = 'Stage.1';  Fn = 'Save-Backup' },
                    @{ Key = 'Stage.2';  Fn = 'Repair-Proxy' },
                    @{ Key = 'Stage.3';  Fn = 'Repair-Hosts' },
                    @{ Key = 'Stage.4';  Fn = 'Repair-NetStack' },
                    @{ Key = 'Stage.5';  Fn = 'Repair-AdapterBinding' },
                    @{ Key = 'Stage.6';  Fn = 'Repair-IpConfig' },
                    @{ Key = 'Stage.7';  Fn = 'Repair-Services' },
                    @{ Key = 'Stage.8';  Fn = 'Repair-AdapterReload' },
                    @{ Key = 'Stage.9';  Fn = 'Repair-Lease' },
                    @{ Key = 'Stage.10'; Fn = 'Repair-NCSI' }
                )

                Push-NR @{ Kind = 'Log'; Level = 'INFO'; Code = 'Log.Start' }
                Push-NR @{ Kind = 'Progress'; Percent = 0 }

                $i = 0
                foreach ($st in $stages) {
                    $i++
                    Set-NRStage $i $total $st.Key
                    $fn = [string]$st.Fn
                    $has = $false
                    try { $has = [bool](Get-Command $fn -CommandType Function -ErrorAction SilentlyContinue) } catch { $has = $false }
                    if (-not $has) {
                        Push-NR @{ Kind = 'Log'; Level = 'ERR'; Code = 'Err.StageMissing'; Arg = $fn }
                        continue
                    }
                    try { & $fn } catch {
                        Push-NR @{ Kind = 'Log'; Level = 'ERR'; Code = 'Err.StageCrash'; Arg = $fn }
                    }
                }

                # --- 验证 ---
                $i++
                Set-NRStage $i $total 'Stage.Verify'
                try {
                    if ([bool](Get-Command 'Test-FinalState' -CommandType Function -ErrorAction SilentlyContinue)) {
                        $verify = Test-FinalState
                    }
                } catch { $verify = $null }
                $passCount = 0
                $verifyTotal = 0
                try {
                    if ($null -ne $verify) {
                        if ($verify.ContainsKey('Pass')) { $passCount = [int]$verify['Pass'] }
                        if ($verify.ContainsKey('Total')) { $verifyTotal = [int]$verify['Total'] }
                    }
                } catch { }

                $netOk = $false
                try {
                    if ($null -ne $verify) {
                        if ($verify.ContainsKey('TcpAny') -and [bool]$verify['TcpAny']) { $netOk = $true }
                        if (-not $netOk -and $verify.ContainsKey('HttpOk') -and [bool]$verify['HttpOk']) { $netOk = $true }
                        if (-not $netOk -and $verify.ContainsKey('PingAny') -and [bool]$verify['PingAny']) { $netOk = $true }
                        if (-not $netOk -and $verify.ContainsKey('DnsAny') -and [bool]$verify['DnsAny']) { $netOk = $true }
                    }
                } catch { }

                # --- 第二轮补救：第一轮没通才跑 ---
                if (-not $netOk -and -not $Deep) {
                    Push-NR @{ Kind = 'Log'; Level = 'WARN'; Code = 'Log.Round2' }
                    $Deep = $true      # 让 Repair-Proxy / Repair-NetStack 走进 [深度] 分支
                    $rescue = @(
                        @{ Key = 'Stage.2';  Fn = 'Repair-Proxy' },
                        @{ Key = 'Stage.4';  Fn = 'Repair-NetStack' },
                        @{ Key = 'Stage.6';  Fn = 'Repair-IpConfig' },
                        @{ Key = 'Stage.7';  Fn = 'Repair-Services' },
                        @{ Key = 'Stage.9';  Fn = 'Repair-Lease' },
                        @{ Key = 'Stage.10'; Fn = 'Repair-NCSI' }
                    )
                    $j = 0
                    foreach ($st in $rescue) {
                        $j++
                        Set-NRStage $j $total $st.Key
                        $fn = [string]$st.Fn
                        if ([bool](Get-Command $fn -CommandType Function -ErrorAction SilentlyContinue)) {
                            try { & $fn } catch { Push-NR @{ Kind = 'Log'; Level = 'ERR'; Code = 'Err.StageCrash'; Arg = $fn } }
                        }
                    }

                    # 公共 DNS 兜底（DHCP 没下发 DNS 时唯一的救命手段）
                    Set-NRStage 6 $total 'Stage.6'
                    $dn = 0
                    try {
                        if ([bool](Get-Command 'Get-IPv4State' -CommandType Function -ErrorAction SilentlyContinue)) {
                            foreach ($s in (Get-IPv4State)) {
                                if ($s.IsVirtual) { continue }
                                if ([string]$s.Status -ne 'Up') { continue }
                                try {
                                    Set-DnsClientServerAddress -InterfaceIndex $s.IfIndex -ServerAddresses @('223.5.5.5', '119.29.29.29') -ErrorAction Stop
                                    $dn++
                                } catch { }
                            }
                        }
                    } catch { }
                    Push-NR @{ Kind = 'Log'; Level = 'WARN'; Code = 'Log.RescueDns'; Arg = [string]$dn }

                    $i++
                    Set-NRStage $i $total 'Stage.Verify'
                    $verify = $null
                    try {
                        if ([bool](Get-Command 'Test-FinalState' -CommandType Function -ErrorAction SilentlyContinue)) {
                            $verify = Test-FinalState
                        }
                    } catch { }
                    try {
                        if ($null -ne $verify) {
                            if ($verify.ContainsKey('Pass')) { $passCount = [int]$verify['Pass'] }
                            if ($verify.ContainsKey('Total')) { $verifyTotal = [int]$verify['Total'] }
                        }
                    } catch { }
                    $netOk = $false
                    try {
                        if ($null -ne $verify) {
                            if ($verify.ContainsKey('TcpAny') -and [bool]$verify['TcpAny']) { $netOk = $true }
                            if (-not $netOk -and $verify.ContainsKey('HttpOk') -and [bool]$verify['HttpOk']) { $netOk = $true }
                            if (-not $netOk -and $verify.ContainsKey('PingAny') -and [bool]$verify['PingAny']) { $netOk = $true }
                            if (-not $netOk -and $verify.ContainsKey('DnsAny') -and [bool]$verify['DnsAny']) { $netOk = $true }
                        }
                    } catch { }
                }

                if ($netOk) { $finalState = 'Success' }
                elseif ($passCount -gt 0) { $finalState = 'Warn' }
                else { $finalState = 'Fail' }

                Push-NR @{ Kind = 'Progress'; Percent = 100 }
            }
        } else {
            Push-NR @{ Kind = 'Progress'; Percent = 100 }
        }
    } catch {
        Push-NR @{ Kind = 'Log'; Level = 'ERR'; Text = $_.Exception.Message }
    } finally {
        try { $sw.Stop() } catch { }
        $secs = 0
        try { $secs = [int][math]::Round($sw.Elapsed.TotalSeconds, 0) } catch { }
        $ok = 0; $fl = 0; $sk = 0
        try { if ($null -ne $script:OKCount) { $ok = [int]$script:OKCount } } catch { }
        try { if ($null -ne $script:FailCount) { $fl = [int]$script:FailCount } } catch { }
        try { if ($null -ne $script:SkipCount) { $sk = [int]$script:SkipCount } } catch { }

        Push-NR @{
            Kind    = 'Done'
            State   = $finalState
            OK      = $ok
            Fail    = $fl
            Skip    = $sk
            Pass    = $passCount
            Total   = $verifyTotal
            Seconds = $secs
        }
    }
}


# =============================================================================
#  15. 启动 / 回收后台任务
# =============================================================================

function Test-HasBackup {
    try {
        $root = Join-Path $env:ProgramData 'NpcNetRepair'
        if (-not (Test-Path -LiteralPath $root)) { return $false }
        $d = @(Get-ChildItem -LiteralPath $root -Directory -Filter 'backup_*' -ErrorAction SilentlyContinue)
        return ($d.Count -gt 0)
    } catch { return $false }
}

function Stop-BackgroundRun {
    try {
        if ($null -ne $script:Ps -and $null -ne $script:AsyncHandle) {
            if ($script:AsyncHandle.IsCompleted) { $null = $script:Ps.EndInvoke($script:AsyncHandle) }
        }
    } catch { }
    try { if ($null -ne $script:Ps) { $script:Ps.Stop() } } catch { }
    try { if ($null -ne $script:Ps) { $script:Ps.Dispose() } } catch { }
    try { if ($null -ne $script:Runspace) { $script:Runspace.Close() } } catch { }
    try { if ($null -ne $script:Runspace) { $script:Runspace.Dispose() } } catch { }
    $script:Ps = $null
    $script:Runspace = $null
    $script:AsyncHandle = $null
}

function Start-BackgroundRun {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Mode,
        [bool]$Deep = $false,
        [int]$TotalSteps = 11
    )

    Stop-BackgroundRun

    $rs = $null
    $ps = $null
    try {
        $rs = [runspacefactory]::CreateRunspace()
        # 后台也用 STA：WPF 相关类型在 MTA 线程里做 COM 调用容易出怪问题
        $rs.ApartmentState = [System.Threading.ApartmentState]::STA
        $rs.ThreadOptions = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
        $rs.Open()

        $ps = [PowerShell]::Create()
        $ps.Runspace = $rs
        [void]$ps.AddScript($script:WorkerBody.ToString())
        [void]$ps.AddParameter('Queue', $script:UiQueue)
        [void]$ps.AddParameter('EngineSource', $Source)
        [void]$ps.AddParameter('Mode', $Mode)
        [void]$ps.AddParameter('Deep', $Deep)
        [void]$ps.AddParameter('TotalSteps', $TotalSteps)

        $script:Runspace = $rs
        $script:Ps = $ps
        $script:AsyncHandle = $ps.BeginInvoke()
    } catch {
        try { if ($null -ne $ps) { $ps.Dispose() } } catch { }
        try { if ($null -ne $rs) { $rs.Close(); $rs.Dispose() } } catch { }
        $script:Ps = $null
        $script:Runspace = $null
        $script:AsyncHandle = $null
        $script:Running = $false
        Update-Log -Level 'ERR' -Text ((T 'Err.WorkerStart') + ' ' + $_.Exception.Message)
        Set-UIState -State 'Fail'
    }
}

function Reset-RunUi {
    Clear-LogList
    Update-Progress -Percent 0
    Update-Detail -Text ''
    $st = Get-Ctl 'StageText'
    if ($null -ne $st) { try { $st.Text = '' } catch { } }
    $script:RingLength = 0.0
    $script:RingDashReady = $false
}

function Start-RepairRun {
    param([switch]$Deep)

    # --- 防误触闸门 -------------------------------------------------------
    # 实测事故：窗口被 SetForegroundWindow 夺焦点的那一刻，可能撞上外部的
    # 鼠标/焦点事件，把"开始修复"直接按下去，程序在用户还没看清界面时
    # 就开始改网络配置。窗口出现后 900ms 内一律忽略启动请求。
    if ($null -ne $script:UiArmedAt) {
        if ((Get-Date) -lt $script:UiArmedAt) { return }
    }

    if (-not (Test-OnUiThread)) {
        Push-UiEvent @{ Kind = 'State'; Value = 'Running' }
        return
    }
    if ($script:Running) { return }

    $engineText = ''
    try { $engineText = Get-EngineSourceText } catch { $engineText = '' }
    if ([string]::IsNullOrWhiteSpace($engineText)) {
        Update-Log -Level 'ERR' -Text (T 'Err.NoEngine')
        Set-UIState -State 'Fail'
        return
    }

    $src = ''
    try {
        $src = Get-EngineCallableSource -Text $engineText
    } catch {
        Update-Log -Level 'ERR' -Text ((T 'Err.EngineParse') + ' :: ' + $_.Exception.Message)
        Set-UIState -State 'Fail'
        return
    }
    if ([string]::IsNullOrWhiteSpace($src)) {
        Update-Log -Level 'ERR' -Text (T 'Err.EngineParse')
        Set-UIState -State 'Fail'
        return
    }

    Reset-RunUi
    $script:Running = $true
    Set-UIState -State 'Running'
    Update-Stage -Index 1 -Total $script:StageTotal -Name (T 'Stage.1')
    Start-BackgroundRun -Source $src -Mode 'Repair' -Deep ([bool]$Deep) -TotalSteps $script:StageTotal
}

function Start-RollbackRun {
    # 与 Start-RepairRun 同一道防误触闸门：窗口弹出瞬间不接受任何改动操作
    if ($null -ne $script:UiArmedAt) {
        if ((Get-Date) -lt $script:UiArmedAt) { return }
    }

    if (-not (Test-OnUiThread)) { return }
    if ($script:Running) { return }

    if (-not (Test-HasBackup)) {
        Update-Log -Level 'WARN' -Text (T 'Log.NoBackup')
        Set-UIState -State 'Warn'
        return
    }

    $engineText = ''
    try { $engineText = Get-EngineSourceText } catch { $engineText = '' }
    if ([string]::IsNullOrWhiteSpace($engineText)) {
        Update-Log -Level 'ERR' -Text (T 'Err.NoEngine')
        Set-UIState -State 'Fail'
        return
    }
    $src = ''
    try { $src = Get-EngineCallableSource -Text $engineText } catch {
        Update-Log -Level 'ERR' -Text ((T 'Err.EngineParse') + ' :: ' + $_.Exception.Message)
        Set-UIState -State 'Fail'
        return
    }

    Reset-RunUi
    $script:Running = $true
    Set-UIState -State 'Running'
    Update-Stage -Index 1 -Total 2 -Name (T 'Stage.RollbackHosts')
    Start-BackgroundRun -Source $src -Mode 'Rollback' -Deep $false
}


# =============================================================================
#  16. 入口
# =============================================================================

function Initialize-Npc修复网络GUI {
    try {
        Initialize-HostRuntime
    } catch {
        try {
            Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
            [void][System.Windows.MessageBox]::Show(('WPF runtime unavailable: ' + $_.Exception.Message), 'NpcNetRepair')
        } catch { }
        return
    }

    Hide-HostConsole
    Initialize-HostLocalization

    $script:SelfPath = Get-SelfPath

    # STA / 管理员：能拉起新进程就拉起，拉不起来就降级继续（窗口照开，按钮禁用）
    $relaunched = $false
    try { $relaunched = Restart-ForEnvironment } catch { $relaunched = $false }
    if ($relaunched) { return }

    $script:NoAdmin = -not (Test-Admin)

    Initialize-UiPipeline

    $win = $null
    try {
        $win = Build-Npc修复网络Window -ThemeText $script:XamlTheme -AnimText $script:XamlAnimations -LayoutText $script:XamlLayout -LangTag $script:XmlLang
    } catch {
        $msg = (T 'Err.Xaml') + "`r`n`r`n" + $_.Exception.Message
        try { [void][System.Windows.MessageBox]::Show($msg, (T 'Ask.Title'), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) } catch { }
        return
    }
    if ($null -eq $win) {
        try { [void][System.Windows.MessageBox]::Show((T 'Err.Xaml'), (T 'Ask.Title'), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) } catch { }
        return
    }

    $script:Window = $win

    $missing = Register-Npc修复网络Controls -Win $win
    $global:GUI['L10n'] = $script:L10n

    Set-RenderTransformPresets
    Set-ControlDefaults
    Apply-LocalizedStatic
    Attach-UiEvents

    # 主按钮武装时间：窗口出现后 900ms 内忽略点击 / 回滚请求，防止弹出瞬间被误触
    $script:UiArmedAt = (Get-Date).AddMilliseconds(900)
    $script:Running = $false

    Start-FlushTimer

    $win.Add_Loaded({
        try {
            Update-Progress -Percent 0
            Set-UIState -State 'Idle'
            Start-UIAnimation -Key 'Sb.PanelFadeIn'
        } catch { }

        # ParticleLayer 默认留空：里面一个粒子都没有，动它等于动空气，
        # 整层位移还会连带影响子元素观感（Agent B 实测 bug 3）。
        # 想要粒子层的话把开关打开并让视觉层往里填粒子。
        if ($script:EnableParticles) {
            try { Start-UIAnimation -Key 'Sb.ParticleDrift' } catch { }
        }

        # 正常路径也要留一行启动日志，否则日志区全黑，用户会以为程序没反应
        # （主控实测反馈第 3 条）。
        try { Update-Log -Level 'DIM' -Text (T 'Log.Boot' @($script:AppVersion)) } catch { }

        if ($script:NoAdmin) {
            Update-Log -Level 'ERR' -Text (T 'Log.NoAdmin')
            Set-UIState -State 'Fail'
            $b = Get-Ctl 'StartButton'
            if ($null -ne $b) { try { $b.IsEnabled = $false } catch { } }
        }

        if ($missing.Count -gt 0) {
            Update-Log -Level 'WARN' -Text ('missing controls: ' + ($missing -join ', '))
        }

        $eng = ''
        try { $eng = Get-EngineSourceText } catch { $eng = '' }
        if ([string]::IsNullOrWhiteSpace($eng)) {
            Update-Log -Level 'WARN' -Text (T 'Log.NoEngine')
        }
    })

    try { [void]$win.ShowDialog() } catch {
        try { [void][System.Windows.MessageBox]::Show(((T 'Err.Init') + "`r`n`r`n" + $_.Exception.Message), (T 'Ask.Title'), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) } catch { }
        return
    }

    # ShowDialog 返回 = 窗口已关闭，做最后回收（Closed 里已经做过一次，这里兜底）
    try { Stop-FlushTimer } catch { }
    try { Stop-AllAnimations } catch { }
    try { Stop-BackgroundRun } catch { }
}


# =============================================================================
#  17. 兼容别名（契约 §3.7 用的是 Start-Animation / Stop-Animation）
# =============================================================================

try { Set-Alias -Name 'Start-Animation' -Value 'Start-UIAnimation' -Force -Scope Global } catch { }
try { Set-Alias -Name 'Stop-Animation'  -Value 'Stop-UIAnimation'  -Force -Scope Global } catch { }

# =============================================================================
#  END OF HOST LAYER
#  主控在该片段之后追加：
#      Initialize-Npc修复网络GUI
#  这是唯一允许的启动方式（内部 ShowDialog 阻塞，保证进程不提前退出）
# =============================================================================


# =============================================================================
#  入口 —— 由 _merge.ps1 自动追加
#  必须放在文件最末尾：ScriptBlock 全部定义完毕后才能真正启动消息循环。
# =============================================================================

Initialize-Npc修复网络GUI
