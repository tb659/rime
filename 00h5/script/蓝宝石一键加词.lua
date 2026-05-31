--[[
--无障碍版专用脚本
--用途：快捷加词
--如何使用: 请参考群文件：同文无障碍版lua脚本使用说明.pdf
--配置说明
第①步 将 快捷加词.lua 文件放置 rime/script 文件夹内
第②步 向主题方案中加入按键
以 XXX.trime.yaml主题方案为例

preset_keys:
  yjjc_lua: {label: 快捷加词, send: function, command: '加词自动编码【定长】.lua', option: "《《命令行》》【【词库名.txt】】【【单字码表名】】【【1】】"}#加词模式 1为弹出输入框，2为在第三方输入框添加，词库名称和单字码表名为自定义项，可以不是单字表，但是建议使用单字表，(PS：码表文件太大会卡死
  yjjc_lua2: {label: 快捷加词, send: function, command: '加词自动编码【定长】.lua', option: "《《命令行》》【【词库名.txt】】【【单字码表名】】【【2】】"}#加词模式 1为弹出输入框，2为在第三方输入框添加，词库名称和单字码表名为自定义项，可以不是单字表，但是建议使用单字表，(PS：码表文件太大会卡死
向任意按键加入上述按键既可

或者在脚本启动器运行，这个时候就需要修改本文件的，40、41、42行
]]
require "import"
import "android.widget.*"
import "android.view.*"
import "android.widget.EditText"
import "android.widget.Toast"
import "android.widget.GridView"
import "android.widget.CardView"
import "android.widget.FrameLayout"
import "android.widget.Button"
import "android.view.Gravity"
import "android.graphics.RectF"
import "java.io.File"
import "android.widget.LinearLayout"
import "android.widget.TextView"
import "android.content.Context"
import "android.widget.ListView"
import "android.graphics.drawable.StateListDrawable"
import "com.androlua.LuaDialog"
import "android.graphics.drawable.Icon"
import "com.androlua.LuaAdapter"
import "com.androlua.LuaDrawable"
import "android.widget.PopupWindow"

local 加词模式="1" --加词模式 1为弹出输入框，二为在第三方输入框添加
local 词库文件名="SapphirePro_yhc.txt"
local 单字码表名="SapphirePro_danzi.txt"--单字码表，可以不是单字表，但是建议使用单字表，(PS：码表文件太大会卡死
local 版本号="1.0.0"
local 参数=(...)
local 输入法目录=tostring(service.getLuaExtDir(""))
local 脚本目录=输入法目录.."/script"
local 脚本路径=debug.getinfo(1,"S").source:sub(2)--获取Lua脚本的完整路径
local 纯脚本名=File(脚本路径).getName()
local 目录=string.sub(脚本路径,1,#脚本路径-#纯脚本名)
local 脚本相对路径=string.sub(脚本路径,#脚本目录+1)
if 参数~=nil && string.find(参数,"《《命令行》》")!=nil then
  词库文件名 = 参数:match("》》【【(.-)】】【【")
  单字码表名 = 参数:match("】】【【(.-)】】【【")
  加词模式= 参数:match("】】【【.-】】【【(.-)】】$")
end
local 词库文件路径=输入法目录.."/"..词库文件名
local 单字码表路径=输入法目录.."/"..单字码表名

local function debugTxt(info)
  info = info or ""
  local file_path = 输入法目录.."/debug.txt"
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local new_line = string.format("[%s] %s", timestamp, info)
  
  local lines = {}
  
  -- 读取现有所有行
  local file = io.open(file_path, "r")
  if file then
    for line in file:lines() do
      table.insert(lines, line)
    end
    file:close()
  end
  
  -- 在最前面插入新行
  table.insert(lines, 1, new_line)
  
  -- 限制行数，避免文件过大（可选）
  local max_lines = 1000
  if #lines > max_lines then
    -- 只保留最新的 max_lines 条
    local new_lines = {}
    for i = 1, max_lines do
      new_lines[i] = lines[i]
    end
    lines = new_lines
  end
  
  -- 重新写入所有行
  file = io.open(file_path, "w")
  if file then
    for i, line in ipairs(lines) do
      file:write(line .. "\n")
    end
    file:close()
  end
end

debugTxt()

local function 数组去重复(数组)
  local exist = {}
  --把相同的元素覆盖掉
  for v, k in pairs(数组) do
    exist[k] = true
  end
  --重新排序表
  local newTable = {}
  for v, k in pairs(exist) do
    table.insert(newTable, v)
  end
  return newTable
end

local function 获取编码(词条)
  -- 先构建一个字到编码的映射表（只做一次）
  if not 字到编码表 then
    字到编码表 = {}
    debugTxt("开始加载码表: " .. 单字码表路径)
    
    local 行数 = 0
    local 字数统计 = 0
    local 编码统计 = 0
    
    for line in io.lines(单字码表路径) do
      行数 = 行数 + 1
      
      -- 跳过空行
      if line ~= "" then
        -- 解析行：字、编码
        local 字, 编码, 权重 = line:match("([^\t]+)\t([^\t]+)")
        if 字 and 编码 then
          -- 去除可能的空白字符
          字 = 字:match("^%s*(.-)%s*$")
          编码 = 编码:match("^%s*(.-)%s*$")
          if 字 ~= "" and 编码 ~= "" and #编码 >= 2 then
            -- 如果同一个字有多个编码，保存到表里
            if not 字到编码表[字] then
              字到编码表[字] = {}
              字数统计 = 字数统计 + 1
            end
            table.insert(字到编码表[字], 编码)
            编码统计 = 编码统计 + 1
          end
        end
      end
    end
    
    debugTxt(string.format("码表加载完成：共%d行，%d个字，%d个编码", 
      行数, 字数统计, 编码统计))
  end
  
  -- 获取词条中每个字的编码
  local 每个字的编码 = {}
  for i = 1, utf8.len(词条) do
    local 字 = utf8.sub(词条, i, i)
    if 字到编码表[字] then
      每个字的编码[i] = 字到编码表[字]
      debugTxt(string.format("字[%s] 有%d个编码", 字, #字到编码表[字]))
    else
      debugTxt("警告：字[" .. 字 .. "]不在码表中")
      return {}  -- 如果有字不在码表中，返回空
    end
  end
  
  local n = #每个字的编码
  local 编码组 = {}
  
  if n == 2 then
    -- 两字词：取每个编码的前两位字母
    for _, code1 in ipairs(每个字的编码[1]) do
      for _, code2 in ipairs(每个字的编码[2]) do
        table.insert(编码组,
          string.sub(code1, 1, 2) ..
          string.sub(code2, 1, 2))
      end
    end
    debugTxt("两字词生成 " .. #编码组 .. " 个编码")
    
  elseif n == 3 then
    -- 三字词：前两个首字母 + 第三个前两位字母
    for _, code1 in ipairs(每个字的编码[1]) do
      for _, code2 in ipairs(每个字的编码[2]) do
        for _, code3 in ipairs(每个字的编码[3]) do
          table.insert(编码组, 
            string.sub(code1, 1, 1) .. 
            string.sub(code2, 1, 1) .. 
            string.sub(code3, 1, 2))
        end
      end
    end
    debugTxt("三字词生成 " .. #编码组 .. " 个编码")
    
  elseif n >= 4 then
    -- 多字词：取1,2,3,尾字的首字母
    for _, code1 in ipairs(每个字的编码[1]) do
      for _, code2 in ipairs(每个字的编码[2]) do
        for _, code3 in ipairs(每个字的编码[3]) do
          for _, codelast in ipairs(每个字的编码[n]) do
            table.insert(编码组, 
              string.sub(code1, 1, 1) .. 
              string.sub(code2, 1, 1) .. 
              string.sub(code3, 1, 1) .. 
              string.sub(codelast, 1, 1))
          end
        end
      end
    end
    debugTxt(string.format("%d字词生成 %d 个编码", n, #编码组))
  end
  
  -- 去重
  local seen = {}
  local result = {}
  for _, code in ipairs(编码组) do
    if not seen[code] then
      seen[code] = true
      table.insert(result, code)
    end
  end
  
  debugTxt(string.format("去重后剩余 %d 个编码", #result))
  
  -- 显示前几个编码示例
  if #result > 0 then
    local 示例 = ""
    for i = 1, math.min(5, #result) do
      示例 = 示例 .. result[i] .. " "
    end
    debugTxt("编码示例: " .. 示例)
  end
  
  return result
end

local function 刷新方案()
  if Rime.select_schema(Rime.getSchemaId().."")==false print("方案刷新失败") end
end
local function 写入词库(字符串, 词库文件)
    -- 解析传入的字符串
    local 词条, 编码 = 字符串:match("([^\t]+)\t([^\t]+)")
    if not 词条 or not 编码 then
        debugTxt("错误：字符串格式不正确 - " .. 字符串)
        return
    end
    
    -- 组装带权重的格式
    local 内容 = 词条 .. "\t1122\t" .. 编码
    
    -- 检查文件是否存在并读取
    local 文件 = io.open(词库文件, "r")
    if 文件 then
        for line in 文件:lines() do
            -- 检查是否已存在相同词条
            debugTxt(line)
            if line == 内容 then
                文件:close()
                debugTxt("已存在: " .. line)
                return
            end
        end
        文件:close()
    end
    
    -- 不存在则写入
    文件 = io.open(词库文件, "a+")
    if 文件 then
        文件:write("\n" .. 内容)
        文件:close()
        debugTxt("添加成功: " .. 内容)
        刷新方案()
    else
        debugTxt("错误：无法打开文件 " .. 词库文件)
    end
end
local function 加词位置按照字母表顺序(路径,词条,编码)
  local d={}
  for c in io.lines(路径) do
    if c:find("	")~=nil then
      d[#d+1]=c:match("	(.+)")
    end
  end
  d[#d+1]=编码
  table.sort(d)
  for i=1, #d do
    if d[i]==编码 then
      内容=io.open(路径):read("*a")
      io.open(路径,"w+"):write(tostring(内容:gsub("\t"..d[i-1],"\t"..d[i-1].."\n"..词条.."\t"..编码))):close()
    end
  end
  刷新方案()
end
local function 一键加词重码选择函数(项目组)
  local ids={}
  local data={}
  local item={LinearLayout,
    layout_width=-1,
    layout_height="30dp",
    padding="2dp",
    orientation="vertical",
    gravity=17,
    {CardView,
      radius="5dp",
      layout_height="36dp",
      CardElevation=0,
      layout_width=-1,
      BackgroundColor=0x49d3d7da,
      --gravity=3|17,
      {LinearLayout,
        layout_width=-1,
        --BackgroundColor=0x49d3d7da,
        --gravity=3|17,
        {TextView,
          id="b",
          textColor=0xffAA7700,
          textSize="14dp"},
        {TextView,
          id="a",
          padding="8dp",
          --gravity=17,
          layout_width=-1,
          gravity="center",
          --BackgroundColor=0x49d3d7da,
          textColor=0xff232323,
          textSize="14dp"}
      }
    }
  }
  local layout=
  {LinearLayout,
    gravity="right",
    layout_height=-1,
    {LinearLayout,
      id="main",
      orientation=1,
      --右侧功能键宽度
      layout_weight=1,
      layout_height=-1,
      layout_gravity=8|3,
      {GridView, --列表控件
        id="list",
        numColumns=1, --6列
        paddingLeft="2dp",
        paddingRight="2dp",
        layout_width=-1,
        layout_weight=1}},
  }
  local adp=LuaAdapter(service,data,item)
  local function fresh(t)
    table.clear(data)
    for i=1,#t do
      local v=t[i]
      local a,b,c=v:match("^%s*([^\n]+)(\n*[^\n]*)(\n*[^\n]*)")
      a=table.concat{utf8.sub(a or "",1,99),utf8.sub(b or "",1,99),utf8.sub(c or "",1,99)}
      table.insert(data,{b=tostring(i),a=a})
    end
    adp.notifyDataSetChanged()
  end
  弹出布局=loadlayout(layout,ids)
  ids.list.Adapter=adp
  fresh(项目组)
  local height=service.getLastKeyboardHeight()
  local width=service.getWidth()--取键盘宽度
  local 宽度,高度=width*0.35,height*0.38
  local popWnd = PopupWindow(this);
  popWnd.setContentView(弹出布局);
  popWnd.setWidth(宽度) --设置显示宽度
  popWnd.setHeight(高度) --设置显示高度
  --popWnd.setFocusable(false);设置焦点
  popWnd.setOutsideTouchable(true)--点击外面区域消失
  --相对某个控件的位置（正左下方），无偏移
  --popWnd.showAsDropDown(v)
  --相对某个控件的位置，有偏移;xoff表示x轴的偏移，正值表示向左，负值表示向右；yoff表示相对y轴的偏移，正值是向下，负值是向上；
  --popWnd.showAsDropDown(View anchor, int xoff, int yoff)
  --相对于父控件的位置（例如正中央Gravity.CENTER，下方Gravity.BOTTOM,Gravity.TOP,Gravity.RIGHT等），可以设置偏移或无偏移
  local v=service.getCandidateView()
  popWnd.showAtLocation(v,Gravity.TOP, 0, 0)
  ids.list.onItemClick=function(l,v,p)
    popWnd.dismiss()
    写入词库(项目组[p+1],词库文件路径)
  end
  ids.list.onItemLongClick=function(l,v,p)
    print(项目组[p+1])
    return true
  end
end
local function 快捷加词重码选择模块(项目组)
  local ids={}
  local data={}
  local item={LinearLayout,
    layout_width=-1,
    layout_height="30dp",
    padding="2dp",
    orientation="vertical",
    gravity=17,
    {CardView,
      radius="5dp",
      layout_height="36dp",
      CardElevation=0,
      layout_width=-1,
      BackgroundColor=0x49d3d7da,
      --gravity=3|17,
      {LinearLayout,
        layout_width=-1,
        --BackgroundColor=0x49d3d7da,
        --gravity=3|17,
        {TextView,
          id="b",
          textColor=0xffAA7700,
          textSize="14dp"},
        {TextView,
          id="a",
          padding="8dp",
          --gravity=17,
          layout_width=-1,
          gravity="center",
          --BackgroundColor=0x49d3d7da,
          textColor=0xff232323,
          textSize="14dp"}}}}
  local adp=LuaAdapter(service,data,item)
  local function fresh(t)
    table.clear(data)
    for i=1,#t do
      local v=t[i]
      local a,b,c=v:match("^%s*([^\n]+)(\n*[^\n]*)(\n*[^\n]*)")
      a=table.concat{utf8.sub(a or "",1,99),utf8.sub(b or "",1,99),utf8.sub(c or "",1,99)}
      table.insert(data,{b=tostring(i),a=a})
    end
    adp.notifyDataSetChanged()
  end
  local function Back() --生成功能键背景
    local bka=LuaDrawable(function(c,p,d)
      local b=d.bounds
      b=RectF(b.left,b.top,b.right,b.bottom)
      p.setColor(0xffffffff)
      c.drawRoundRect(b,20,20,p) --圆角20
    end)
    local bkb=LuaDrawable(function(c,p,d)
      local b=d.bounds
      b=RectF(b.left,b.top,b.right,b.bottom)
      p.setColor(0x49d3d7da)
      c.drawRoundRect(b,20,20,p)
    end)
    local stb=StateListDrawable()
    stb.addState({-android.R.attr.state_pressed},bkb)
    stb.addState({android.R.attr.state_pressed},bka)
    return stb
  end
  local function Icon(k,s) --获取k功能图标，没有返回s
    k=Key.presetKeys[k]
    return k and k.label or s
  end
  local function Bu_R(id) --生成功能键
    local Bu={LinearLayout,
      layout_height=-1,
      layout_width=-1,
      layout_weight=1,
      padding="2dp",
      {FrameLayout,
        layout_height=-1,
        layout_width=-1,
        Background=Back(),
        {TextView,
          gravity=17|48,
          layout_height=-1,
          layout_width=-1,
          layout_marginTop="2dp",
          textColor=0xff232323,
          textSize="10dp"},
        {TextView,
          gravity=17,
          layout_height=-1,
          layout_width=-1,
          textColor=0xff232323,
          textSize="18dp"}}}
    local msg=Bu[2][2] --上标签
    local label=Bu[2][3] --主标签
    if id==1 then
      label.text=Icon("关闭","关闭")
      Bu.onClick=function()
        dialog.dismiss()
      end
    end
    return Bu
  end
  local layout={LinearLayout,
    orientation=1,
    --键盘高度
    layout_width=-1,
    --背景颜色
    --BackgroundColor=0xffd7dddd,
    {TextView,
      id="title",
      layout_height="30dp",
      layout_width=-1,
      text="",
      gravity="center",
      paddingLeft="2dp",
      paddingRight="2dp",
      BackgroundColor=0x49d3d7da
    },
    {LinearLayout,
      gravity="right",
      layout_height=-1,
      {LinearLayout,
        id="main",
        orientation=1,
        --右侧功能键宽度
        layout_weight=1,
        layout_height=-1,
        layout_gravity=8|3,
        {GridView, --列表控件
          id="list",
          numColumns=1, --6列
          paddingLeft="2dp",
          paddingRight="2dp",
          layout_width=-1,
          layout_weight=1}},
      {LinearLayout,
        orientation=1,
        layout_weight=1,
        layout_width="100dp",
        layout_height=-1,
        --layout_gravity=5|84,
        Bu_R(1),
      },
  }}
  layout=loadlayout(layout,ids)
  ids.list.Adapter=adp
  fresh(项目组)
  local 标题="重码选择模块1.0"
  ids.title.setText(标题)
  ids.list.onItemClick=function(l,v,p)
    写入词库(项目组[p+1],词库文件路径)
    dialog.dismiss()
    print()
  end
  ids.list.onItemLongClick=function(l,v,p)
    print(项目组[p+1])
    return true
  end
  local Bus={LinearLayout,
    paddingLeft="2dp",
    layout_width=-1}
  ids.main.addView(loadlayout(Bus))
  local dl=LuaDialog(service)
  .setView(layout)
  dl.show()
  dialog=dl.show()
end
layout={
  LinearLayout,
  orientation="vertical",
  {
    LinearLayout,
    layout_width="fill",
    orientation="horizontal",
    layout_height="145",
    gravity="center",
    {
      Button,
      id="citiao",
      text="词条 ：",
      layout_weight="1",
    },
    {
      EditText,
      id="edit",
      layout_weight="20",
      Hint="请在此处输入词条",
      singleLine=true, --设置单行输入
    }
  },
  {
    LinearLayout,
    layout_width="fill",
    orientation="horizontal",
    layout_height="145",
    gravity="center",
    {
      Button,
      id="bianma",
      text="编码 ：",
      layout_weight="1",
    },
    {
      EditText,
      id="edit2",
      layout_weight="20",
      Hint="请在此处输入编码",
      singleLine=true, --设置单行输入
    }
  },
  {
    LinearLayout,
    layout_width="fill",
    orientation="horizontal",
    layout_height="145",
    gravity="center",
    {
      Button,
      id="quxiao",
      text="取消",
      layout_weight="1",
    },
    {
      Button,
      id="shengcheng",
      text="生成",
      layout_weight="1",
    },
    {
      Button,
      id="queding",
      text="确定",
      layout_weight="1",
    }
  }
}
if 加词模式=="1" then
  local ids,layout2={},{LinearLayout,
    --键盘高度
    layout_height=service.getLastKeyboardHeight(),
    layout_width=-1,
    --背景颜色，默认透明
    BackgroundColor=0x88ffffff,
    {ListView,
      id="list",
      layout_width=-1}}
  layout2=loadlayout(layout2,ids)
  local data,item={},{LinearLayout,
    layout_width=-1,
    padding="4dp",
    gravity=3|17,
    {TextView,
      id="a",
      textColor=0xff232323,
      textSize="15dp"},
    {TextView,
      id="b",
      gravity=3|17,
      paddingLeft="4dp",
      --最大显示行数
      MaxLines=3,
      --最小高度
      MinHeight="30dp",
      textColor=0xff232323,
      textSize="25dp"}}
  local adp=LuaAdapter(service,data,item)
  ids.list.Adapter=adp
  local dl=LuaDialog(service)
  .setTitle(纯脚本名:sub(1,-5)..版本号)
  .setView(loadlayout(layout))
  dl.show()
  dialog=dl.show()
  local function 获取词条和编码()
    local 词条=""
    if service.getClipBoard().toString() ~="[]" then
      词条=service.getClipBoard()[0] --读取剪切板数组"从0开始"
      edit.setHint(service.getClipBoard()[0])
    end
    if edit.getText().toString()~="" then
      词条= edit.getText().toString()
    end
    local 编码=""
    local 编码组0=获取编码(词条)
    
    if #编码组0==1 then
      edit2.setText(编码组0[1])
      编码=编码组0[1]
     elseif #编码组0>1 then
      local 词条编码组={}
      for i =1,#编码组0 do
        词条编码组[i]=词条.."\t"..编码组0[i]
      end
      快捷加词重码选择模块(词条编码组)
    end
  end
  --自动编码提示
  获取词条和编码()
  shengcheng.onClick=function()
    获取词条和编码()
    return true
  end
  queding.onClick=function()
    local 词条=edit.getText().toString()
    local 编码=edit2.getText().toString()
    if 编码=="" or 编码==nil then
      获取词条和编码()
      编码=edit2.getText().toString()
    end
    if 词条==nil or 词条=="" then
      词条=service.getClipBoard()[0] --读取剪切板数组"从0开始"
    end
    local 词条和编码=词条.."\t"..编码
    if 词条和编码~="	" and 词条~=nil and 编码~=nil then
      写入词库(词条和编码,词库文件路径)
    end
    dialog.dismiss()
  end
  citiao.onClick=function()
    edit.setText(service.getClipBoard()[0])
  end
  quxiao.onClick=function()
    print("取消")
    dialog.dismiss()
  end
  --自动弹出输入法
  task(100,function()
    --让页面上的某个控件获得焦点，比如edit,则可以通过如下代码实现：
    edit.setFocusable(true);
    edit.setFocusableInTouchMode(true);
    edit.requestFocus();
    local imm = service.getSystemService(Context.INPUT_METHOD_SERVICE)
    imm.showSoftInput(edit, 0)
  end)--间隔时间间
 elseif 加词模式=="2" then
  service.sendEvent({send= "Control+a"})--全选
  --取编辑框选中内容,部分app内无效
  local 选中内容=service.getCurrentInputConnection()
  if 选中内容~=nil then
    选中内容=选中内容.getSelectedText(0)
  end
  if 选中内容==nil then
    import "android.content.Context" --导入类
    选中内容=service.getSystemService(Context.CLIPBOARD_SERVICE).getText() --获取剪贴板
  end
  local 新增词组内容=选中内容
  if 新增词组内容== nil or 新增词组内容=="" then
    do return end --强制退出
  end
  local 编码组=获取编码(新增词组内容)
  if #编码组==1 then
    写入词库(新增词组内容.."\t"..编码组[1],词库文件路径)
   elseif #编码组>1 then
    print("有重码")
    local 词条编码组={}
    for i =1,#编码组 do
      词条编码组[i]=新增词组内容.."\t"..编码组[i]
    end
    一键加词重码选择函数(词条编码组)
  end--if#编码组
end