-- Some simple dialog screens

local _ENV = mkmodule('gui.dialogs')

local gui = require('gui')
local utils = require('utils')

local dscreen = dfhack.screen

MessageBox = defclass(MessageBox, gui.FramedScreen)

MessageBox.focus_path = 'MessageBox'
MessageBox.frame_style = gui.GREY_LINE_FRAME

function MessageBox:init(info)
    info = info or {}
    self:init_fields{
        text = info.text or {},
        frame_title = info.title,
        frame_width = info.frame_width,
        on_accept = info.on_accept,
        on_cancel = info.on_cancel,
        on_close = info.on_close,
        text_pen = info.text_pen
    }
    if type(self.text) == 'string' then
        self.text = utils.split_string(self.text, "\n")
    end
    gui.FramedScreen.init(self, info)
    return self
end

function MessageBox:getWantedFrameSize()
    local text = self.text
    local w = #(self.frame_title or '') + 4
    w = math.max(w, 20)
    w = math.max(self.frame_width or w, w)
    for _, l in ipairs(text) do
        w = math.max(w, #l)
    end
    local h = #text+1
    if h > 1 then
        h = h+1
    end
    return w+2, #text+2
end

function MessageBox:onRenderBody(dc)
    if #self.text > 0 then
        dc:newline(1):pen(self.text_pen or COLOR_GREY)
        for _, l in ipairs(self.text or {}) do
            dc:string(l):newline(1)
        end
    end

    if self.on_accept then
        local x,y = self.frame_rect.x1+1, self.frame_rect.y2+1
        dscreen.paintString({fg=COLOR_LIGHTGREEN},x,y,'ESC')
        dscreen.paintString({fg=COLOR_GREY},x+3,y,'/')
        dscreen.paintString({fg=COLOR_LIGHTGREEN},x+4,y,'y')
    end
end

function MessageBox:onDestroy()
    if self.on_close then
        self.on_close()
    end
end

function MessageBox:onInput(keys)
    if keys.MENU_CONFIRM then
        self:dismiss()
        if self.on_accept then
            self.on_accept()
        end
    elseif keys.LEAVESCREEN or (keys.SELECT and not self.on_accept) then
        self:dismiss()
        if self.on_cancel then
            self.on_cancel()
        end
    end
end

function showMessage(title, text, tcolor, on_close)
    mkinstance(MessageBox):init{
        text = text,
        title = title,
        text = text,
        text_pen = tcolor,
        on_close = on_close
    }:show()
end

function showYesNoPrompt(title, text, tcolor, on_accept, on_cancel)
    mkinstance(MessageBox):init{
        title = title,
        text = text,
        text_pen = tcolor,
        on_accept = on_accept,
        on_cancel = on_cancel,
    }:show()
end

InputBox = defclass(InputBox, MessageBox)

InputBox.focus_path = 'InputBox'

function InputBox:init(info)
    info = info or {}
    self:init_fields{
        input = info.input or '',
        input_pen = info.input_pen,
        on_input = info.on_input,
    }
    MessageBox.init(self, info)
    self.on_accept = nil
    return self
end

function InputBox:getWantedFrameSize()
    local mw, mh = MessageBox.getWantedFrameSize(self)
    return mw, mh+2
end

function InputBox:onRenderBody(dc)
    MessageBox.onRenderBody(self, dc)

    dc:newline(1)
    dc:pen(self.input_pen or COLOR_LIGHTCYAN)
    dc:fill(1,dc:localY(),dc.width-2,dc:localY())

    local cursor = '_'
    if math.floor(dfhack.getTickCount()/300) % 2 == 0 then
        cursor = ' '
    end
    local txt = self.input .. cursor
    if #txt > dc.width-2 then
        txt = string.char(27)..string.sub(txt, #txt-dc.width+4)
    end
    dc:string(txt)
end

function InputBox:onInput(keys)
    if keys.SELECT then
        self:dismiss()
        if self.on_input then
            self.on_input(self.input)
        end
    elseif keys.LEAVESCREEN then
        self:dismiss()
        if self.on_cancel then
            self.on_cancel()
        end
    elseif keys._STRING then
        if keys._STRING == 0 then
            self.input = string.sub(self.input, 1, #self.input-1)
        else
            self.input = self.input .. string.char(keys._STRING)
        end
    end
end

function showInputPrompt(title, text, tcolor, input, on_input, on_cancel, min_width)
    mkinstance(InputBox):init{
        title = title,
        text = text,
        text_pen = tcolor,
        input = input,
        on_input = on_input,
        on_cancel = on_cancel,
        frame_width = min_width,
    }:show()
end

ListBox = defclass(ListBox, MessageBox)

ListBox.focus_path = 'ListBox'

function ListBox:init(info)
    info = info or {}
    self:init_fields{
        selection = info.selection or 0,
    	choices = info.choices or {},
        select_pen = info.select_pen,
        on_input = info.on_input,
		page_top = 0
    }
    MessageBox.init(self, info)
    self.on_accept = nil
    return self
end

function ListBox:getWantedFrameSize()
    local mw, mh = MessageBox.getWantedFrameSize(self)
    return mw, mh+#self.choices
end

function ListBox:onRenderBody(dc)
    MessageBox.onRenderBody(self, dc)
	
    dc:newline(1)
	
	if self.selection>dc.height-3 then
		self.page_top=self.selection-(dc.height-3)
	elseif self.selection<self.page_top and self.selection >0  then
		self.page_top=self.selection-1
	end
	for i,entry in ipairs(self.choices) do
		if type(entry)=="table" then
			entry=entry[1]
		end
		if i>self.page_top then
			if i == self.selection then
				dc:pen(self.select_pen or COLOR_LIGHTCYAN)
			else
				dc:pen(self.text_pen or COLOR_GREY)
			end
			dc:string(entry)
			dc:newline(1)
		end
	end
end
function ListBox:moveCursor(delta)
	local newsel=self.selection+delta
	if #self.choices ~=0 then
		if newsel<1 or newsel>#self.choices then 
			newsel=newsel % #self.choices
		end
	end
	self.selection=newsel
end
function ListBox:onInput(keys)
    if keys.SELECT then
        self:dismiss()
		local choice=self.choices[self.selection]
        if self.on_input then
            self.on_input(self.selection,choice)
        end
		
		if choice and choice[2] then
			choice[2](choice,self.selection) -- maybe reverse the arguments?
		end
    elseif keys.LEAVESCREEN then
        self:dismiss()
        if self.on_cancel then
            self.on_cancel()
        end
	elseif keys.CURSOR_UP then
		self:moveCursor(-1)
	elseif keys.CURSOR_DOWN then
		self:moveCursor(1)
	elseif keys.CURSOR_UP_FAST then
		self:moveCursor(-10)
	elseif keys.CURSOR_DOWN_FAST then
		self:moveCursor(10)
    end
end

function showListPrompt(title, text, tcolor, choices, on_input, on_cancel, min_width)
    mkinstance(ListBox):init{
        title = title,
        text = text,
        text_pen = tcolor,
        choices = choices,
        on_input = on_input,
        on_cancel = on_cancel,
        frame_width = min_width,
    }:show()
end

return _ENV
