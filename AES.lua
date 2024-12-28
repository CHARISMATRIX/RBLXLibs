local pads = {}
local modes = {}

do
	local function nonPad(text)
		return text
	end
	pads.None = table.freeze({
		Pad = nonPad, Unpad = nonPad,
		Overwrite = false
	})

	local function anxPad(text, out, segm)
		local len = buffer.len(text)
		local offs = len - len % segm
		if out then
			assert(buffer.len(out) >= len + segm, "Output buffer out of bounds")
			local offb = segm - len % segm
			buffer.copy(out, 0, text, 0, len)
			buffer.fill(out, len, 0, offb - 1)
			buffer.writeu8(out, offs + segm - 1, offb)
		else
			offs += segm
			out = buffer.create(offs)
			buffer.copy(out, 0, text, 0, len)
			buffer.writeu8(out, offs - 1, segm - len % segm)
		end
		return out
	end
	local function anxUnpad(text, out, segm)
		local len = buffer.len(text)
		local offs = buffer.readu8(text, len - 1)
		local offb = len - offs
		assert(0 < offs and offs <= segm, "Got unexpected padding")
		for offs = offb, len - 2 do
			if buffer.readu8(text, offs) ~= 0 then
				error("Got unexpected padding")
			end
		end
		if out then
			assert(buffer.len(out) >= offb, "Output buffer out of bounds")
		else
			out = buffer.create(offb)
		end
		buffer.copy(out, 0, text, 0, offb)
		return out
	end

	local function i10Pad(text, out, segm)
		local len = buffer.len(text)
		local offs = len - len % segm
		if out then
			assert(buffer.len(out) >= len + segm, "Output buffer out of bounds")
		else
			out = buffer.create(offs + segm)
		end
		buffer.copy(out, 0, text, 0, len)
		for offs = len, offs + segm - 2 do
			buffer.writeu8(out, offs, math.random(0, 255))
		end
		buffer.writeu8(out, offs + segm - 1, segm - len % segm)
		return out
	end
	local function i10Unpad(text, out, segm)
		local len = buffer.len(text)
		local offs = buffer.readu8(text, len - 1)
		local offb = len - offs
		assert(0 < offs and offs <= segm, "Got unexpected padding")
		if out then
			assert(buffer.len(out) >= offb, "Output buffer out of bounds")
		else
			out = buffer.create(offb)
		end
		buffer.copy(out, 0, text, 0, offb)
		return out
	end

	local function pksPad(text, out, segm)
		local len = buffer.len(text)
		local offs = len - len % segm
		if out then
			assert(buffer.len(out) >= len + segm, "Output buffer out of bounds")
		else
			out = buffer.create(offs + segm)
		end
		local offb = segm - len % segm
		buffer.copy(out, 0, text, 0, len)
		buffer.fill(out, len, offb, offb)
		return out
	end
	local function pksUnpad(text, out, segm)
		local len = buffer.len(text)
		local offs = buffer.readu8(text, len - 1)
		local offb = len - offs
		assert(0 < offs and offs <= segm, "Got unexpected padding")
		for offb = offb, len - 2 do
			if buffer.readu8(text, offb) ~= offs then
				error("Got unexpected padding")
			end
		end
		if out then
			assert(buffer.len(out) >= offb, "Output buffer out of bounds")
		else
			out = buffer.create(offb)
		end
		buffer.copy(out, 0, text, 0, offb)
		return out
	end

	local function ii7Pad(text, out, segm)
		local len = buffer.len(text)
		if out then
			assert(buffer.len(out) >= len + segm, "Output buffer out of bounds") 
			buffer.fill(out, len + 1, 0, segm - len % segm - 1)
		else
			out = buffer.create(len + segm - len % segm)
		end
		buffer.copy(out, 0, text, 0, len)
		buffer.writeu8(out, len, 128)
		return out
	end
	local function ii7Unpad(text, out, segm)
		local len = buffer.len(text) - 1
		local byte
		for offs = len, len - segm, - 1 do
			byte = buffer.readu8(text, offs)
			if byte == 128 then
				if out then
					assert(buffer.len(out) >= offs, "Output buffer out of bounds")
				else
					out = buffer.create(offs)
				end
				buffer.copy(out, 0, text, 0, offs)
				return out
			else
				assert(byte == 0, "Got unexpected padding")
			end
		end
		error("Got unexpected padding")
		return buffer.create(0)
	end

	local function zroPad(text, out, segm)
		local len = buffer.len(text)
		if out then
			assert(buffer.len(out) >= len + segm, "Output buffer out of bounds")
			buffer.fill(out, len, 0, segm - len % segm)
		else
			out = buffer.create(len + segm - len % segm)
		end
		buffer.copy(out, 0, text, 0, len)
		return out
	end
	local function zroUnpad(text, out, segm)
		local len = buffer.len(text) - 1
		local byte
		for offs = len, len - segm, - 1 do
			byte = buffer.readu8(text, offs)
			if byte == 0 then
				offs += 1
				if out then
					assert(buffer.len(out) >= offs, "Output buffer out of bounds")
				else
					out = buffer.create(offs)
				end
				buffer.copy(out, 0, text, 0, offs)
				return out
			end
		end
		buffer.copy(out, 0, text, 0, len - segm - 1)
		return out
	end

	local meta = {
		__index = function(_, idx: "AnsiX923" | "Iso10126" | "Pkcs7" | "Iso7816_4" | "Zero"): {}?
			return if idx == "AnsiX923" then {
				Pad = anxPad, Unpad = anxPad,
				Overwrite = nil
			} elseif idx == "Iso10126" then {
					Pad = i10Pad, Unpad = i10Unpad,
					Overwrite = nil
				} elseif idx == "Pkcs7" then {
					Pad = pksPad, Unpad = pksUnpad,
					Overwrite = nil
				} elseif idx == "Iso7816_4" then {
					Pad = ii7Pad, Unpad = ii7Unpad,
					Overwrite = nil
				} elseif idx == "Zero" then {
					Pad = zroPad, Unpad = zroUnpad,
					Overwrite = nil
				} else nil
		end,
		__newindex = function() end
	}
	setmetatable(pads, meta)
	pads.AnsiX923 = 	{} :: {Pad: (buffer, buffer?, number) -> buffer, Unpad: (buffer, buffer?, number) -> buffer, Overwrite: nil | boolean}
	pads.Iso10126 = 	{} :: {Pad: (buffer, buffer?, number) -> buffer, Unpad: (buffer, buffer?, number) -> buffer, Overwrite: nil | boolean}
	pads.Pkcs7 = 		{} :: {Pad: (buffer, buffer?, number) -> buffer, Unpad: (buffer, buffer?, number) -> buffer, Overwrite: nil | boolean}
	pads.Iso7816_4 = 	{} :: {Pad: (buffer, buffer?, number) -> buffer, Unpad: (buffer, buffer?, number) -> buffer, Overwrite: nil | boolean}
	pads.Zero = 		{} :: {Pad: (buffer, buffer?, number) -> buffer, Unpad: (buffer, buffer?, number) -> buffer, Overwrite: nil | boolean}
	table.freeze(pads)
	meta.__metatable = "This metatable is locked"
end
do
	local ZEROES = buffer.create(16)

	local function addByteCtr(ctr: buffer, step: number, offs0: number, offs1: number, le: boolean): ()
		local byte
		if le then
			byte = buffer.readu8(ctr, offs0) + step
			buffer.writeu8(ctr, offs0, byte)
			if byte >= 256 then
				for offs = offs0 + 1, offs1 do
					byte = buffer.readu8(ctr, offs) + 1
					buffer.writeu8(ctr, offs, byte)
					if byte < 256 then
						break
					end
				end
			end
		else
			byte = buffer.readu8(ctr, offs1) + step
			buffer.writeu8(ctr, offs1, byte)
			if byte >= 256 then
				for offs = offs1 - 1, offs0, - 1 do
					byte = buffer.readu8(ctr, offs) + 1
					buffer.writeu8(ctr, offs, byte)
					if byte < 256 then
						break
					end
				end
			end
		end
	end

	modes.ECB = table.freeze({
		FwdMode = function(encp, _, text, out)
			local len = buffer.len(text) - 16
			assert(len % 16 == 0, "Input length must be a multiple of 16 bytes")
			for offs = 0, len, 16 do
				encp(text, offs, out, offs)
			end
		end,
		InvMode = function(_, decp, ciph, out)
			local len = buffer.len(ciph) - 16
			assert(len % 16 == 0, "Input length must be a multiple of 16 bytes")
			for offs = 0, len, 16 do
				decp(ciph, offs, out, offs)
			end
		end
	})

	modes.CBC = table.freeze({
		FwdMode = function(encp, _, text, out, _, iv)
			local len = buffer.len(text) - 16
			assert(len % 16 == 0, "Input length must be a multiple of 16 bytes")
			iv = iv or ZEROES
			assert(buffer.len(iv) == 16, "Initialization vector must be 16 bytes long")
			buffer.writeu32(out, 0, bit32.bxor(buffer.readu32(text, 0), buffer.readu32(iv, 0)))
			buffer.writeu32(out, 4, bit32.bxor(buffer.readu32(text, 4), buffer.readu32(iv, 4)))
			buffer.writeu32(out, 8, bit32.bxor(buffer.readu32(text, 8), buffer.readu32(iv, 8)))
			buffer.writeu32(out, 12, bit32.bxor(buffer.readu32(text, 12), buffer.readu32(iv, 12)))
			encp(out, 0, out, 0)
			for offs = 16, len, 16 do
				buffer.writeu32(out, offs, bit32.bxor(buffer.readu32(text, offs), buffer.readu32(out, offs - 16)))
				buffer.writeu32(out, offs + 4, bit32.bxor(buffer.readu32(text, offs + 4), buffer.readu32(out, offs - 12)))
				buffer.writeu32(out, offs + 8, bit32.bxor(buffer.readu32(text, offs + 8), buffer.readu32(out, offs - 8)))
				buffer.writeu32(out, offs + 12, bit32.bxor(buffer.readu32(text, offs + 12), buffer.readu32(out, offs - 4)))
				encp(out, offs, out, offs)
			end
		end,
		InvMode = function(_, decp, ciph, out, _, iv)
			local len = buffer.len(ciph) - 16
			assert(len % 16 == 0, "Input length must be a multiple of 16 bytes")
			iv = iv or ZEROES
			assert(buffer.len(iv) == 16, "Initialization vector must be 16 bytes long")
			local w0 = buffer.readu32(ciph, 0); local w1 = buffer.readu32(ciph, 4)
			local w2 = buffer.readu32(ciph, 8); local w3 = buffer.readu32(ciph, 12)
			local w4, w5, w6, w7
			decp(ciph, 0, out, 0)
			buffer.writeu32(out, 0, bit32.bxor(buffer.readu32(out, 0), buffer.readu32(iv, 0)))
			buffer.writeu32(out, 4, bit32.bxor(buffer.readu32(out, 4), buffer.readu32(iv, 4)))
			buffer.writeu32(out, 8, bit32.bxor(buffer.readu32(out, 8), buffer.readu32(iv, 8)))
			buffer.writeu32(out, 12, bit32.bxor(buffer.readu32(out, 12), buffer.readu32(iv, 12)))
			for offs = 16, len, 16 do
				w4 = buffer.readu32(ciph, offs)
				w5 = buffer.readu32(ciph, offs + 4)
				w6 = buffer.readu32(ciph, offs + 8)
				w7 = buffer.readu32(ciph, offs + 12)
				decp(ciph, offs, out, offs)
				buffer.writeu32(out, offs, bit32.bxor(buffer.readu32(out, offs), w0))
				buffer.writeu32(out, offs + 4, bit32.bxor(buffer.readu32(out, offs + 4), w1))
				buffer.writeu32(out, offs + 8, bit32.bxor(buffer.readu32(out, offs + 8), w2))
				buffer.writeu32(out, offs + 12, bit32.bxor(buffer.readu32(out, offs + 12), w3))
				w0, w1, w2, w3 = w4, w5, w6, w7
			end
		end
	})

	modes.PCBC = table.freeze({
		FwdMode = function(encp, _, text, out, _, iv)
			local len = buffer.len(text) - 16
			assert(len % 16 == 0, "Input length must be a multiple of 16 bytes")
			iv = iv or ZEROES
			assert(buffer.len(iv) == 16, "Initialization vector must be 16 bytes long")
			local w0 = buffer.readu32(text, 0); local w1 = buffer.readu32(text, 4)
			local w2 = buffer.readu32(text, 8); local w3 = buffer.readu32(text, 12)
			local w4, w5, w6, w7
			buffer.writeu32(out, 0, bit32.bxor(w0, buffer.readu32(iv, 0)))
			buffer.writeu32(out, 4, bit32.bxor(w1, buffer.readu32(iv, 4)))
			buffer.writeu32(out, 8, bit32.bxor(w2, buffer.readu32(iv, 8)))
			buffer.writeu32(out, 12, bit32.bxor(w3, buffer.readu32(iv, 12)))
			encp(out, 0, out, 0)
			for offs = 16, len, 16 do
				w4 = buffer.readu32(text, offs)
				w5 = buffer.readu32(text, offs + 4)
				w6 = buffer.readu32(text, offs + 8)
				w7 = buffer.readu32(text, offs + 12)
				buffer.writeu32(out, offs, bit32.bxor(w0, w4, buffer.readu32(out, offs - 16)))
				buffer.writeu32(out, offs + 4, bit32.bxor(w1, w5, buffer.readu32(out, offs - 12)))
				buffer.writeu32(out, offs + 8, bit32.bxor(w2, w6, buffer.readu32(out, offs - 8)))
				buffer.writeu32(out, offs + 12, bit32.bxor(w3, w7, buffer.readu32(out, offs - 4)))
				encp(out, offs, out, offs)
				w0, w1, w2, w3 = w4, w5, w6, w7
			end
		end,
		InvMode = function(_, decp, ciph, out, _, iv)
			local len = buffer.len(ciph) - 16
			assert(len % 16 == 0, "Input length must be a multiple of 16 bytes")
			iv = iv or ZEROES
			assert(buffer.len(iv) == 16, "Initialization vector must be 16 bytes long")
			local w0 = buffer.readu32(ciph, 0); local w1 = buffer.readu32(ciph, 4)
			local w2 = buffer.readu32(ciph, 8); local w3 = buffer.readu32(ciph, 12)
			decp(ciph, 0, out, 0)
			local w4 = bit32.bxor(buffer.readu32(out, 0), buffer.readu32(iv, 0))
			local w5 = bit32.bxor(buffer.readu32(out, 4), buffer.readu32(iv, 4))
			local w6 = bit32.bxor(buffer.readu32(out, 8), buffer.readu32(iv, 8))
			local w7 = bit32.bxor(buffer.readu32(out, 12), buffer.readu32(iv, 12))
			local w8, w9, w10, w11
			buffer.writeu32(out, 0, w4)
			buffer.writeu32(out, 4, w5)
			buffer.writeu32(out, 8, w6)
			buffer.writeu32(out, 12, w7)
			local offp0, offp1, offp2, offp3 = 0, 4, 8, 12
			for offs = 16, len, 16 do
				offp0 += 16; offp1 += 16; offp2 += 16; offp3 += 16
				w8 = buffer.readu32(ciph, offp0)
				w9 = buffer.readu32(ciph, offp1)
				w10 = buffer.readu32(ciph, offp2)
				w11 = buffer.readu32(ciph, offp3)
				decp(ciph, offs, out, offs)
				w4 = bit32.bxor(w0, w4, buffer.readu32(out, offp0))
				w5 = bit32.bxor(w1, w5, buffer.readu32(out, offp1))
				w6 = bit32.bxor(w2, w6, buffer.readu32(out, offp2))
				w7 = bit32.bxor(w3, w7, buffer.readu32(out, offp3))
				w0, w1, w2, w3 = w8, w9, w10, w11
				buffer.writeu32(out, offp0, w4)
				buffer.writeu32(out, offp1, w5)
				buffer.writeu32(out, offp2, w6)
				buffer.writeu32(out, offp3, w7)
			end
		end
	})

	local function cfbFwd(encp, _, text, out, options: {CommonTemp: buffer, SegmentSize: number}, iv)
		local segm = options.SegmentSize
		local len = buffer.len(text)
		assert(len % segm == 0, "Input length must be a multiple of segment size")
		iv = iv or ZEROES
		assert(buffer.len(iv) == 16, "Initialization vector must be 16 bytes long")
		local temp = options.CommonTemp or buffer.create(31)
		if len == segm then
			encp(iv, 0, temp, 0)
			for offs = 0, segm - 1 do
				buffer.writeu8(out, offs, bit32.bxor(buffer.readu8(text, offs), buffer.readu8(temp, offs)))
			end
		else
			local last = len - segm; local offb = 16 - segm
			local i
			encp(iv, 0, temp, 0)
			for offs = 0, segm - 1 do
				buffer.writeu8(out, offs, bit32.bxor(buffer.readu8(text, offs), buffer.readu8(temp, offs)))
			end
			buffer.copy(temp, 0, iv, segm, offb)
			buffer.copy(temp, offb, out, 0, segm)
			for offs = segm, last - segm, segm do
				i = 0
				buffer.copy(temp, 16, temp, segm, offb)
				encp(temp, 0, temp, 0)
				for offs = offs, offs + segm - 1 do
					buffer.writeu8(out, offs, bit32.bxor(buffer.readu8(text, offs), buffer.readu8(temp, i)))
					i += 1
				end
				buffer.copy(temp, 0, temp, 16, offb)
				buffer.copy(temp, offb, out, offs, segm)
			end
			encp(temp, 0, temp, 0)
			i = 0
			for offs = last, len - 1 do
				buffer.writeu8(out, offs, bit32.bxor(buffer.readu8(text, offs), buffer.readu8(temp, i)))
				i += 1
			end
		end
	end
	local function cfbInv(encp, _, ciph, out, options: {CommonTemp: buffer, SegmentSize: number}, iv)
		local len = buffer.len(ciph)
		local segm = options.SegmentSize
		assert(len % segm == 0, "Input length must be a multiple of segment size")
		iv = iv or ZEROES
		assert(buffer.len(iv) == 16, "Initialization vector must be 16 bytes long")
		local temp = options.CommonTemp or buffer.create(31)
		if len == segm then
			encp(iv, 0, temp, 0)
			for offs = 0, segm - 1 do
				buffer.writeu8(out, offs, bit32.bxor(buffer.readu8(ciph, offs), buffer.readu8(temp, offs)))
			end
		else
			local last = len - segm; local offb = 16 - segm
			local i
			encp(iv, 0, temp, 0)
			for offs = 0, segm - 1 do
				buffer.writeu8(out, offs, bit32.bxor(buffer.readu8(ciph, offs), buffer.readu8(temp, offs)))
			end
			buffer.copy(temp, 0, iv, segm, offb)
			buffer.copy(temp, offb, ciph, 0, segm)
			for offs = segm, last - segm, segm do
				i = 0
				buffer.copy(temp, 16, temp, segm, offb)
				encp(temp, 0, temp, 0)
				for offs = offs, offs + segm - 1 do
					buffer.writeu8(out, offs, bit32.bxor(buffer.readu8(ciph, offs), buffer.readu8(temp, i)))
					i += 1
				end
				buffer.copy(temp, 0, temp, 16, offb)
				buffer.copy(temp, offb, ciph, offs, segm)
			end
			encp(temp, 0, temp, 0)
			i = 0
			for offs = last, len - 1 do
				buffer.writeu8(out, offs, bit32.bxor(buffer.readu8(ciph, offs), buffer.readu8(temp, i)))
				i += 1
			end
		end
	end

	local function ofbMode(encp, _, text: buffer, out: buffer, _, iv: buffer)
		local len = buffer.len(text) - 16
		assert(len % 16 == 0, "Input length must be a multiple of 16 bytes")
		iv = iv or ZEROES
		assert(buffer.len(iv) == 16, "Initialization vector must be 16 bytes long")
		local w0 = buffer.readu32(text, 0); local w1 = buffer.readu32(text, 4)
		local w2 = buffer.readu32(text, 8); local w3 = buffer.readu32(text, 12)
		encp(iv, 0, out, 0)
		w0 = bit32.bxor(w0, buffer.readu32(out, 0))
		w1 = bit32.bxor(w1, buffer.readu32(out, 4))
		w2 = bit32.bxor(w2, buffer.readu32(out, 8))
		w3 = bit32.bxor(w3, buffer.readu32(out, 12))
		local w4, w5, w6, w7
		for offs = 16, len, 16 do
			w4 = buffer.readu32(text, offs)
			w5 = buffer.readu32(text, offs + 4)
			w6 = buffer.readu32(text, offs + 8)
			w7 = buffer.readu32(text, offs + 12)
			encp(out, offs - 16, out, offs)
			buffer.writeu32(out, offs - 16, w0)
			buffer.writeu32(out, offs - 12, w1)
			buffer.writeu32(out, offs - 8, w2)
			buffer.writeu32(out, offs - 4, w3)
			w0 = bit32.bxor(w4, buffer.readu32(out, offs))
			w1 = bit32.bxor(w5, buffer.readu32(out, offs + 4))
			w2 = bit32.bxor(w6, buffer.readu32(out, offs + 8))
			w3 = bit32.bxor(w7, buffer.readu32(out, offs + 12))
		end
		buffer.writeu32(out, len, w0)
		buffer.writeu32(out, len + 4, w1)
		buffer.writeu32(out, len + 8, w2)
		buffer.writeu32(out, len + 12, w3)
	end
	modes.OFB = table.freeze({
		FwdMode = ofbMode, InvMode = ofbMode
	})

	local function ctrMode(encp, _, text, out, options: {CommonTemp: buffer, InitValue: string, Prefix: string, Suffix: string,
		Step: number, LittleEndian: boolean})
		local len = buffer.len(text) - 16
		assert(len % 16 == 0, "Input length must be a multiple of 16 bytes")
		local temp = options.CommonTemp
		local init = options.InitValue; local pre = options.Prefix
		local suf = options.Suffix; local step = options.Step; local le = options.LittleEndian
		local offs0 = #pre; local offs1 = offs0 + #init - 1
		buffer.writestring(temp, 0, pre)
		buffer.writestring(temp, offs0, init)
		buffer.writestring(temp, offs1 + 1, suf)
		local w0 = buffer.readu32(text, 0); local w1 = buffer.readu32(text, 4)
		local w2 = buffer.readu32(text, 8); local w3 = buffer.readu32(text, 12)
		encp(temp, 0, out, 0)
		buffer.writeu32(out, 0, bit32.bxor(buffer.readu32(out, 0), w0))
		buffer.writeu32(out, 4, bit32.bxor(buffer.readu32(out, 4), w1))
		buffer.writeu32(out, 8, bit32.bxor(buffer.readu32(out, 8), w2))
		buffer.writeu32(out, 12, bit32.bxor(buffer.readu32(out, 12), w3))
		for offs = 16, len, 16 do
			w0 = buffer.readu32(text, offs)
			w1 = buffer.readu32(text, offs + 4)
			w2 = buffer.readu32(text, offs + 8)
			w3 = buffer.readu32(text, offs + 12)
			addByteCtr(temp, step, offs0, offs1, le)
			encp(temp, 0, out, offs)
			buffer.writeu32(out, offs, bit32.bxor(w0, buffer.readu32(out, offs)))
			buffer.writeu32(out, offs + 4, bit32.bxor(w1, buffer.readu32(out, offs + 4)))
			buffer.writeu32(out, offs + 8, bit32.bxor(w2, buffer.readu32(out, offs + 8)))
			buffer.writeu32(out, offs + 12, bit32.bxor(w3, buffer.readu32(out, offs + 12)))
		end
	end

	local meta = {
		__index = function(_, idx: "CFB" | "CTR"): {}?
			return if idx == "CFB" then {
				FwdMode = cfbFwd, InvMode = cfbInv,
				SegmentSize = 16,
				CommonTemp = buffer.create(31)
			} elseif idx == "CTR" then {
					FwdMode = ctrMode, InvMode = ctrMode,
					InitValue = string.pack("I2I2I2I2I2I2I2I2", math.random(0, 65535), math.random(0, 65535), math.random(0, 65535),
						math.random(0, 65535), math.random(0, 65535), math.random(0, 65535), math.random(0, 65535), math.random(0, 65535)),
					Prefix = "", Suffix = "", Step = 1, LittleEndian = false,
					CommonTemp = buffer.create(16)
				} else nil
		end,
		__newindex = function()
		end
	}
	setmetatable(modes, meta)
	modes.CFB = {} :: {FwdMode: typeof(cfbFwd), InvMode: typeof(cfbInv), CommonTemp: buffer, SegmentSize: number}
	modes.CTR = {} :: {FwdMode: typeof(ctrMode), InvMode: typeof(ctrMode), CommonTemp: buffer, InitValue: string, Prefix: string, Suffix: string,
		Step: number, LittleEndian: boolean}
	table.freeze(modes)
	meta.__metatable = "This metatable is locked"
end

local S_BOX_16 = 	buffer.create(131072)	
local S_MIX0 = 		buffer.create(65536)	
local S_MIX1 = 		buffer.create(65536)	
local INV_S_XOR = 	buffer.create(65536)	
local INV_MIX0 = 	buffer.create(65536)	
local INV_MIX1 = 	buffer.create(65536)	

local function keySchedule(key: buffer | string, len: number, out: buffer, raw: boolean): buffer
	if raw then 
		buffer.copy(out, 0, key :: buffer, 0, len)
	else		
		buffer.writestring(out, 0, key :: string, len)
	end
	local word = bit32.rrotate(buffer.readu32(out, len - 4), 8) 
	local rc = 0.5 

	if len == 32 then 
		for offs = 32, 192, 32 do
			rc = rc * 2 % 229
			word = bit32.bxor(buffer.readu32(out, offs - 32), buffer.readu16(S_BOX_16, math.floor(word / 65536) * 2) * 65536 +
				buffer.readu16(S_BOX_16, word % 65536 * 2), rc)
			buffer.writeu32(out, offs, word)

			word = bit32.bxor(buffer.readu32(out, offs - 28), word)
			buffer.writeu32(out, offs + 4, word)
			word = bit32.bxor(buffer.readu32(out, offs - 24), word)
			buffer.writeu32(out, offs + 8, word)
			word = bit32.bxor(buffer.readu32(out, offs - 20), word)
			buffer.writeu32(out, offs + 12, word)

			word = bit32.bxor(buffer.readu32(out, offs - 16), buffer.readu16(S_BOX_16, math.floor(word / 65536) * 2) * 65536 +
				buffer.readu16(S_BOX_16, word % 65536 * 2))
			buffer.writeu32(out, offs + 16, word)

			word = bit32.bxor(buffer.readu32(out, offs - 12), word)
			buffer.writeu32(out, offs + 20, word)
			word = bit32.bxor(buffer.readu32(out, offs - 8), word)
			buffer.writeu32(out, offs + 24, word)
			word = bit32.bxor(buffer.readu32(out, offs - 4), word)
			buffer.writeu32(out, offs + 28, word)
			word = bit32.rrotate(word, 8)
		end
		word = bit32.bxor(buffer.readu32(out, 192), buffer.readu16(S_BOX_16, math.floor(word / 65536) * 2) * 65536 +
			buffer.readu16(S_BOX_16, word % 65536 * 2), 64)
		buffer.writeu32(out, 224, word)

		word = bit32.bxor(buffer.readu32(out, 196), word)
		buffer.writeu32(out, 228, word)
		word = bit32.bxor(buffer.readu32(out, 200), word)
		buffer.writeu32(out, 232, word)
		buffer.writeu32(out, 236, bit32.bxor(buffer.readu32(out, 204), word))
	elseif len == 24 then 
		for offs = 24, 168, 24 do
			rc = rc * 2 % 229
			word = bit32.bxor(buffer.readu32(out, offs - 24), buffer.readu16(S_BOX_16, math.floor(word / 65536) * 2) * 65536 +
				buffer.readu16(S_BOX_16, word % 65536 * 2), rc)
			buffer.writeu32(out, offs, word)

			word = bit32.bxor(buffer.readu32(out, offs - 20), word)
			buffer.writeu32(out, offs + 4, word)
			word = bit32.bxor(buffer.readu32(out, offs - 16), word)
			buffer.writeu32(out, offs + 8, word)
			word = bit32.bxor(buffer.readu32(out, offs - 12), word)
			buffer.writeu32(out, offs + 12, word)
			word = bit32.bxor(buffer.readu32(out, offs - 8), word)
			buffer.writeu32(out, offs + 16, word)
			word = bit32.bxor(buffer.readu32(out, offs - 4), word)
			buffer.writeu32(out, offs + 20, word)
			word = bit32.rrotate(word, 8)
		end
		word = bit32.bxor(buffer.readu32(out, 168), buffer.readu16(S_BOX_16, math.floor(word / 65536) * 2) * 65536 +
			buffer.readu16(S_BOX_16, word % 65536 * 2), 128)
		buffer.writeu32(out, 192, word)

		word = bit32.bxor(buffer.readu32(out, 172), word)
		buffer.writeu32(out, 196, word)
		word = bit32.bxor(buffer.readu32(out, 176), word)
		buffer.writeu32(out, 200, word) 
		buffer.writeu32(out, 204, bit32.bxor(buffer.readu32(out, 180), word))
	else 
		for offs = 16, 144, 16 do
			rc = rc * 2 % 229
			word = bit32.bxor(buffer.readu32(out, offs - 16), buffer.readu16(S_BOX_16, math.floor(word / 65536) * 2) * 65536 +
				buffer.readu16(S_BOX_16, word % 65536 * 2), rc)
			buffer.writeu32(out, offs, word)

			word = bit32.bxor(buffer.readu32(out, offs - 12), word)
			buffer.writeu32(out, offs + 4, word)
			word = bit32.bxor(buffer.readu32(out, offs - 8), word)
			buffer.writeu32(out, offs + 8, word)
			word = bit32.bxor(buffer.readu32(out, offs - 4), word)
			buffer.writeu32(out, offs + 12, word)
			word = bit32.rrotate(word, 8)
		end
		word = bit32.bxor(buffer.readu32(out, 144), buffer.readu16(S_BOX_16, math.floor(word / 65536) * 2) * 65536 +
			buffer.readu16(S_BOX_16, word % 65536 * 2), 54)
		buffer.writeu32(out, 160, word)

		word = bit32.bxor(buffer.readu32(out, 148), word)
		buffer.writeu32(out, 164, word)
		word = bit32.bxor(buffer.readu32(out, 152), word)
		buffer.writeu32(out, 168, word)
		buffer.writeu32(out, 172, bit32.bxor(buffer.readu32(out, 156), word))
	end
	return out
end

local function encryptBlock(keym: buffer, lenm: number, text: buffer, offs: number, out: buffer, offt: number): ()

	local b0 = 	bit32.bxor(buffer.readu8(text, offs), buffer.readu8(keym, 0))
	local b1 = 	bit32.bxor(buffer.readu8(text, offs + 1), buffer.readu8(keym, 1))
	local b2 = 	bit32.bxor(buffer.readu8(text, offs + 2), buffer.readu8(keym, 2))
	local b3 =	bit32.bxor(buffer.readu8(text, offs + 3), buffer.readu8(keym, 3))
	local b4 =	bit32.bxor(buffer.readu8(text, offs + 4), buffer.readu8(keym, 4))
	local b5 =	bit32.bxor(buffer.readu8(text, offs + 5), buffer.readu8(keym, 5))
	local b6 =	bit32.bxor(buffer.readu8(text, offs + 6), buffer.readu8(keym, 6))
	local b7 =	bit32.bxor(buffer.readu8(text, offs + 7), buffer.readu8(keym, 7))
	local b8 =	bit32.bxor(buffer.readu8(text, offs + 8), buffer.readu8(keym, 8))
	local b9 =	bit32.bxor(buffer.readu8(text, offs + 9), buffer.readu8(keym, 9))
	local b10 =	bit32.bxor(buffer.readu8(text, offs + 10), buffer.readu8(keym, 10))
	local b11 = bit32.bxor(buffer.readu8(text, offs + 11), buffer.readu8(keym, 11))
	local b12 = bit32.bxor(buffer.readu8(text, offs + 12), buffer.readu8(keym, 12))
	local b13 = bit32.bxor(buffer.readu8(text, offs + 13), buffer.readu8(keym, 13))
	local b14 = bit32.bxor(buffer.readu8(text, offs + 14), buffer.readu8(keym, 14))
	local b15 = bit32.bxor(buffer.readu8(text, offs + 15), buffer.readu8(keym, 15))

	local i0 = b0 * 256 + b5; 	local i1 = b5 * 256 + b10;	local i2 = b10 * 256 + b15; local i3 = b15 * 256 + b0
	local i4 = b4 * 256 + b9; 	local i5 = b9 * 256 + b14;	local i6 = b14 * 256 + b3; 	local i7 = b3 * 256 + b4
	local i8 = b8 * 256 + b13; 	local i9 = b13 * 256 + b2;	local i10 = b2 * 256 + b7; 	local i11 = b7 * 256 + b8
	local i12 = b12 * 256 + b1; local i13 = b1 * 256 + b6;	local i14 = b6 * 256 + b11; local i15 = b11 * 256 + b12

	for offs = 16, lenm, 16 do

		b0 =	bit32.bxor(buffer.readu8(S_MIX0, i0), buffer.readu8(S_MIX1, i2), buffer.readu8(keym, offs))
		b1 =	bit32.bxor(buffer.readu8(S_MIX0, i1), buffer.readu8(S_MIX1, i3), buffer.readu8(keym, offs + 1))
		b2 =	bit32.bxor(buffer.readu8(S_MIX0, i2), buffer.readu8(S_MIX1, i0), buffer.readu8(keym, offs + 2))
		b3 =	bit32.bxor(buffer.readu8(S_MIX0, i3), buffer.readu8(S_MIX1, i1), buffer.readu8(keym, offs + 3))
		b4 =	bit32.bxor(buffer.readu8(S_MIX0, i4), buffer.readu8(S_MIX1, i6), buffer.readu8(keym, offs + 4))
		b5 =	bit32.bxor(buffer.readu8(S_MIX0, i5), buffer.readu8(S_MIX1, i7), buffer.readu8(keym, offs + 5))
		b6 =	bit32.bxor(buffer.readu8(S_MIX0, i6), buffer.readu8(S_MIX1, i4), buffer.readu8(keym, offs + 6))
		b7 =	bit32.bxor(buffer.readu8(S_MIX0, i7), buffer.readu8(S_MIX1, i5), buffer.readu8(keym, offs + 7))
		b8 =	bit32.bxor(buffer.readu8(S_MIX0, i8), buffer.readu8(S_MIX1, i10), buffer.readu8(keym, offs + 8))
		b9 =	bit32.bxor(buffer.readu8(S_MIX0, i9), buffer.readu8(S_MIX1, i11), buffer.readu8(keym, offs + 9))
		b10 =	bit32.bxor(buffer.readu8(S_MIX0, i10), buffer.readu8(S_MIX1, i8), buffer.readu8(keym, offs + 10))
		b11 =	bit32.bxor(buffer.readu8(S_MIX0, i11), buffer.readu8(S_MIX1, i9), buffer.readu8(keym, offs + 11))
		b12 =	bit32.bxor(buffer.readu8(S_MIX0, i12), buffer.readu8(S_MIX1, i14), buffer.readu8(keym, offs + 12))
		b13 =	bit32.bxor(buffer.readu8(S_MIX0, i13), buffer.readu8(S_MIX1, i15), buffer.readu8(keym, offs + 13))
		b14 =	bit32.bxor(buffer.readu8(S_MIX0, i14), buffer.readu8(S_MIX1, i12), buffer.readu8(keym, offs + 14))
		b15 =	bit32.bxor(buffer.readu8(S_MIX0, i15), buffer.readu8(S_MIX1, i13), buffer.readu8(keym, offs + 15))

		i0, i1, i2, i3, i4, i5, i6, i7, i8, i9, i10, i11, i12, i13, i14, i15 =
			b0 * 256 + b5, b5 * 256 + b10, b10 * 256 + b15, b15 * 256 + b0, b4 * 256 + b9, b9 * 256 + b14, b14 * 256 + b3, b3 * 256 + b4,
		b8 * 256 + b13, b13 * 256 + b2, b2 * 256 + b7, b7 * 256 + b8, b12 * 256 + b1, b1 * 256 + b6, b6 * 256 + b11, b11 * 256 + b12
	end

	buffer.writeu32(out, offt, bit32.bxor(buffer.readu16(S_BOX_16, bit32.bxor(buffer.readu8(S_MIX0, i15), buffer.readu8(S_MIX1, i13),
		buffer.readu8(keym, lenm + 31)) * 512 + bit32.bxor(buffer.readu8(S_MIX0, i10), buffer.readu8(S_MIX1, i8), buffer.readu8(keym, lenm + 26)) * 2)
			* 65536 + buffer.readu16(S_BOX_16, bit32.bxor(buffer.readu8(S_MIX0, i5), buffer.readu8(S_MIX1, i7), buffer.readu8(keym, lenm + 21)) * 512 +
				bit32.bxor(buffer.readu8(S_MIX0, i0), buffer.readu8(S_MIX1, i2), buffer.readu8(keym, lenm + 16)) * 2), buffer.readu32(keym, lenm + 32)))
	buffer.writeu32(out, offt + 4, bit32.bxor(buffer.readu16(S_BOX_16, bit32.bxor(buffer.readu8(S_MIX0, i3), buffer.readu8(S_MIX1, i1),
		buffer.readu8(keym, lenm + 19)) * 512 + bit32.bxor(buffer.readu8(S_MIX0, i14), buffer.readu8(S_MIX1, i12), buffer.readu8(keym, lenm + 30)) * 2)
			* 65536 + buffer.readu16(S_BOX_16, bit32.bxor(buffer.readu8(S_MIX0, i9), buffer.readu8(S_MIX1, i11), buffer.readu8(keym, lenm + 25)) * 512 +
				bit32.bxor(buffer.readu8(S_MIX0, i4), buffer.readu8(S_MIX1, i6), buffer.readu8(keym, lenm + 20)) * 2), buffer.readu32(keym, lenm + 36)))
	buffer.writeu32(out, offt + 8, bit32.bxor(buffer.readu16(S_BOX_16, bit32.bxor(buffer.readu8(S_MIX0, i7), buffer.readu8(S_MIX1, i5),
		buffer.readu8(keym, lenm + 23)) * 512 + bit32.bxor(buffer.readu8(S_MIX0, i2), buffer.readu8(S_MIX1, i0), buffer.readu8(keym, lenm + 18)) * 2)
			* 65536 + buffer.readu16(S_BOX_16, bit32.bxor(buffer.readu8(S_MIX0, i13), buffer.readu8(S_MIX1, i15), buffer.readu8(keym, lenm + 29)) * 512 +
				bit32.bxor(buffer.readu8(S_MIX0, i8), buffer.readu8(S_MIX1, i10), buffer.readu8(keym, lenm + 24)) * 2), buffer.readu32(keym, lenm + 40)))
	buffer.writeu32(out, offt + 12, bit32.bxor(buffer.readu16(S_BOX_16, bit32.bxor(buffer.readu8(S_MIX0, i11), buffer.readu8(S_MIX1, i9),
		buffer.readu8(keym, lenm + 27)) * 512 + bit32.bxor(buffer.readu8(S_MIX0, i6), buffer.readu8(S_MIX1, i4), buffer.readu8(keym, lenm + 22)) * 2)
			* 65536 + buffer.readu16(S_BOX_16, bit32.bxor(buffer.readu8(S_MIX0, i1), buffer.readu8(S_MIX1, i3), buffer.readu8(keym, lenm + 17)) * 512 +
				bit32.bxor(buffer.readu8(S_MIX0, i12), buffer.readu8(S_MIX1, i14), buffer.readu8(keym, lenm + 28)) * 2), buffer.readu32(keym, lenm + 44)))
end

local function decryptBlock(keym: buffer, lenm: number, ciph: buffer, offs: number, out: buffer, offt: number): ()

	local b0 = 	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(ciph, offs) * 256 + buffer.readu8(keym, lenm + 32)), buffer.readu8(keym, lenm + 16))
	local b1 = 	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(ciph, offs + 13) * 256 + buffer.readu8(keym, lenm + 45)), buffer.readu8(keym, lenm + 17))
	local b2 = 	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(ciph, offs + 10) * 256 + buffer.readu8(keym, lenm + 42)), buffer.readu8(keym, lenm + 18))
	local b3 = 	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(ciph, offs + 7) * 256 + buffer.readu8(keym, lenm + 39)), buffer.readu8(keym, lenm + 19))
	local b4 = 	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(ciph, offs + 4) * 256 + buffer.readu8(keym, lenm + 36)), buffer.readu8(keym, lenm + 20))
	local b5 = 	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(ciph, offs + 1) * 256 + buffer.readu8(keym, lenm + 33)), buffer.readu8(keym, lenm + 21))
	local b6 = 	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(ciph, offs + 14) * 256 + buffer.readu8(keym, lenm + 46)), buffer.readu8(keym, lenm + 22))
	local b7 = 	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(ciph, offs + 11) * 256 + buffer.readu8(keym, lenm + 43)), buffer.readu8(keym, lenm + 23))
	local b8 = 	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(ciph, offs + 8) * 256 + buffer.readu8(keym, lenm + 40)), buffer.readu8(keym, lenm + 24))
	local b9 = 	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(ciph, offs + 5) * 256 + buffer.readu8(keym, lenm + 37)), buffer.readu8(keym, lenm + 25))
	local b10 = bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(ciph, offs + 2) * 256 + buffer.readu8(keym, lenm + 34)), buffer.readu8(keym, lenm + 26))
	local b11 = bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(ciph, offs + 15) * 256 + buffer.readu8(keym, lenm + 47)), buffer.readu8(keym, lenm + 27))
	local b12 = bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(ciph, offs + 12) * 256 + buffer.readu8(keym, lenm + 44)), buffer.readu8(keym, lenm + 28))
	local b13 = bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(ciph, offs + 9) * 256 + buffer.readu8(keym, lenm + 41)), buffer.readu8(keym, lenm + 29))
	local b14 = bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(ciph, offs + 6) * 256 + buffer.readu8(keym, lenm + 38)), buffer.readu8(keym, lenm + 30))
	local b15 = bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(ciph, offs + 3) * 256 + buffer.readu8(keym, lenm + 35)), buffer.readu8(keym, lenm + 31))

	local i0 = b0 * 256 + b1; 	local i1 = b1 * 256 + b2;	local i2 = b2 * 256 + b3; 	local i3 = b3 * 256 + b0
	local i4 = b4 * 256 + b5; 	local i5 = b5 * 256 + b6; 	local i6 = b6 * 256 + b7; 	local i7 = b7 * 256 + b4
	local i8 = b8 * 256 + b9; 	local i9 = b9 * 256 + b10; 	local i10 = b10 * 256 + b11;local i11 = b11 * 256 + b8
	local i12 = b12 * 256 + b13;local i13 = b13 * 256 + b14;local i14 = b14 * 256 + b15;local i15 = b15 * 256 + b12

	for offs = lenm, 16, - 16 do

		b0 = 	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i0) * 256 + buffer.readu8(INV_MIX1, i2)), buffer.readu8(keym, offs))
		b1 =	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i13) * 256 + buffer.readu8(INV_MIX1, i15)), buffer.readu8(keym, offs + 1))
		b2 =	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i10) * 256 + buffer.readu8(INV_MIX1, i8)), buffer.readu8(keym, offs + 2))
		b3 =	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i7) * 256 + buffer.readu8(INV_MIX1, i5)), buffer.readu8(keym, offs + 3))
		b4 =	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i4) * 256 + buffer.readu8(INV_MIX1, i6)), buffer.readu8(keym, offs + 4))
		b5 =	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i1) * 256 + buffer.readu8(INV_MIX1, i3)), buffer.readu8(keym, offs + 5))
		b6 =	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i14) * 256 + buffer.readu8(INV_MIX1, i12)), buffer.readu8(keym, offs + 6))
		b7 =	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i11) * 256 + buffer.readu8(INV_MIX1, i9)), buffer.readu8(keym, offs + 7))
		b8 =	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i8) * 256 + buffer.readu8(INV_MIX1, i10)), buffer.readu8(keym, offs + 8))
		b9 =	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i5) * 256 + buffer.readu8(INV_MIX1, i7)), buffer.readu8(keym, offs + 9))
		b10 =	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i2) * 256 + buffer.readu8(INV_MIX1, i0)), buffer.readu8(keym, offs + 10))
		b11 =	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i15) * 256 + buffer.readu8(INV_MIX1, i13)), buffer.readu8(keym, offs + 11))
		b12 =	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i12) * 256 + buffer.readu8(INV_MIX1, i14)), buffer.readu8(keym, offs + 12))
		b13 =	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i9) * 256 + buffer.readu8(INV_MIX1, i11)), buffer.readu8(keym, offs + 13))
		b14 =	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i6) * 256 + buffer.readu8(INV_MIX1, i4)), buffer.readu8(keym, offs + 14))
		b15 =	bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i3) * 256 + buffer.readu8(INV_MIX1, i1)), buffer.readu8(keym, offs + 15))

		i0, i1, i2, i3, i4, i5, i6, i7, i8, i9, i10, i11, i12, i13, i14, i15 =
			b0 * 256 + b1, b1 * 256 + b2, b2 * 256 + b3, b3 * 256 + b0, b4 * 256 + b5, b5 * 256 + b6, b6 * 256 + b7, b7 * 256 + b4,
		b8 * 256 + b9, b9 * 256 + b10, b10 * 256 + b11, b11 * 256 + b8, b12 * 256 + b13, b13 * 256 + b14, b14 * 256 + b15, b15 * 256 + b12
	end

	buffer.writeu32(out, offt, bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i7) * 256 + buffer.readu8(INV_MIX1, i5)),
		buffer.readu8(keym, 3)) * 16777216 + bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i10) * 256 + buffer.readu8(INV_MIX1, i8)),
			buffer.readu8(keym, 2)) * 65536 + bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i13) * 256 + buffer.readu8(INV_MIX1, i15)),
			buffer.readu8(keym, 1)) * 256 + bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i0) * 256 + buffer.readu8(INV_MIX1, i2)),
			buffer.readu8(keym, 0)))
	buffer.writeu32(out, offt + 4, bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i11) * 256 + buffer.readu8(INV_MIX1, i9)),
		buffer.readu8(keym, 7)) * 16777216 + bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i14) * 256 + buffer.readu8(INV_MIX1, i12)),
			buffer.readu8(keym, 6)) * 65536 + bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i1) * 256 + buffer.readu8(INV_MIX1, i3)),
			buffer.readu8(keym, 5)) * 256 + bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i4) * 256 + buffer.readu8(INV_MIX1, i6)),
			buffer.readu8(keym, 4)))
	buffer.writeu32(out, offt + 8, bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i15) * 256 + buffer.readu8(INV_MIX1, i13)),
		buffer.readu8(keym, 11)) * 16777216 + bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i2) * 256 + buffer.readu8(INV_MIX1, i0)),
			buffer.readu8(keym, 10)) * 65536 + bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i5) * 256 + buffer.readu8(INV_MIX1, i7)),
			buffer.readu8(keym, 9)) * 256 + bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i8) * 256 + buffer.readu8(INV_MIX1, i10)),
			buffer.readu8(keym, 8)))
	buffer.writeu32(out, offt + 12, bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i3) * 256 + buffer.readu8(INV_MIX1, i1)),
		buffer.readu8(keym, 15)) * 16777216 + bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i6) * 256 + buffer.readu8(INV_MIX1, i4)),
			buffer.readu8(keym, 14)) * 65536 + bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i9) * 256 + buffer.readu8(INV_MIX1, i11)),
			buffer.readu8(keym, 13)) * 256 + bit32.bxor(buffer.readu8(INV_S_XOR, buffer.readu8(INV_MIX0, i12) * 256 + buffer.readu8(INV_MIX1, i14)),
			buffer.readu8(keym, 12)))
end

do
	local S_BOX = 		buffer.create(256) 
	local INV_S_BOX = 	buffer.create(256) 

	local MUL3 = buffer.create(256)
	local MUL9 = buffer.create(256)
	local MUL11 = buffer.create(256)
	local p = 1; local q = 1; local t

	local function gfmul(a: number, b: number): number 
		local p = 0

		for _ = 0, 7 do
			if b % 2 == 1 then
				p = bit32.bxor(p, a)
			end

			if a >= 128 then
				a = bit32.bxor(a * 2 % 256, 27)
			else
				a = a * 2 % 256
			end
			b = math.floor(b / 2)
		end
		return p
	end

	buffer.writeu8(S_BOX, 0, 99) 
	for _ = 1, 255 do 
		p = bit32.bxor(p, p * 2, if p < 128 then 0 else 27) % 256
		q = bit32.bxor(q, q * 2)
		q = bit32.bxor(q, q * 4)
		q = bit32.bxor(q, q * 16) % 256
		if q >= 128 then
			q = bit32.bxor(q, 9)
		end

		t = bit32.bxor(q, q % 128 * 2 + q / 128, q % 64 * 4 + q / 64, q % 32 * 8 + q / 32, q % 16 * 16 + q / 16, 99) 
		buffer.writeu8(S_BOX, p, t)
		buffer.writeu8(INV_S_BOX, t, p)

		buffer.writeu8(MUL3, p, gfmul(3, p))
		buffer.writeu8(MUL9, p, gfmul(9, p))
		buffer.writeu8(MUL11, p, gfmul(11, p))
	end

	local pb, g2, g14, g13; t = 0
	for i = 0, 255 do
		p = buffer.readu8(S_BOX, i); pb = p * 256
		g2, g13, g14 = gfmul(2, p), gfmul(13, i), gfmul(14, i)
		for j = 0, 255 do
			q = buffer.readu8(S_BOX, j)
			buffer.writeu16(S_BOX_16, t * 2, pb + q) 
			buffer.writeu8(INV_S_XOR, t, buffer.readu8(INV_S_BOX, bit32.bxor(i, j)))
			buffer.writeu8(S_MIX0, t, bit32.bxor(g2, buffer.readu8(MUL3, q)))
			buffer.writeu8(S_MIX1, t, bit32.bxor(p, q))
			buffer.writeu8(INV_MIX0, t, bit32.bxor(g14, buffer.readu8(MUL11, j)))
			buffer.writeu8(INV_MIX1, t, bit32.bxor(g13, buffer.readu8(MUL9, j)))
			t += 1
		end
	end
end

export type AesCipher = typeof(setmetatable({} :: { 
	Key: string, Length: number, Mode: {FwdMode: ((input: buffer, offset: number, output: buffer, offsetOut: number) -> (),
		(input: buffer, offset: number, output: buffer, offsetOut: number) -> (), buffer, buffer, {any}, ...any) -> (),
		InvMode: ((input: buffer, offset: number, output: buffer, offsetOut: number) -> (),
			(input: buffer, offset: number, output: buffer, offsetOut: number) -> (), buffer, buffer, {any}, ...any) -> ()},
	Padding: {Pad: (buffer, buffer?, number) -> buffer, Unpad: (buffer, buffer?, number) -> buffer, Overwrite: boolean?}, RoundKeys: string,
	Encrypt: (self: AesCipher, plaintext: buffer | string, output: buffer?, ...any) -> buffer,
	Decrypt: (self: AesCipher, ciphertext: buffer | string, output: buffer?, ...any) -> buffer,
	EncryptBlock: (self: AesCipher, plaintext: buffer, offset: number, output: buffer?, offsetOut: number?) -> (),
	DecryptBlock: (self: AesCipher, ciphertext: buffer, offset: number, output: buffer?, offsetOut: number?) -> (),
	Destroy: (self: AesCipher) -> ()
}, {}))
local function newidx(_, idx)
	return error(`{idx} cannot be assigned to`)
end
local function tostr()
	return "AesCipher"
end
local function expandKey(key: buffer | string, output: buffer?): buffer 
	local raw = typeof(key) == "buffer"
	local len = if raw then buffer.len(key :: buffer) else #(key :: string)
	local lenx = if len == 32 then 240 elseif len == 24 then 208 elseif len == 16 then 176 else error("Key must be either 16, 24 or 32 bytes long")
	return keySchedule(key, len, output or buffer.create(lenx :: number), raw)
end
local function fromKey(roundKeys: buffer, mode: {FwdMode: ((input: buffer, offset: number, output: buffer, offsetOut: number) -> (),
	(input: buffer, offset: number, output: buffer, offsetOut: number) -> (), buffer, buffer, {[string]: any}, ...any) -> (),
	InvMode: ((input: buffer, offset: number, output: buffer, offsetOut: number) -> (),
		(input: buffer, offset: number, output: buffer, offsetOut: number) -> (), buffer, buffer, {[string]: any}, ...any) -> ()}?,
	pad: {Pad: (buffer, buffer?, number) -> buffer, Unpad: (buffer, buffer?, number) -> buffer, Overwrite: boolean?}?): AesCipher
	local len: number? = buffer.len(roundKeys)
	local lenm: number?; local key: string?
	local keyst: string? = buffer.tostring(roundKeys)
	if len == 240 then
		lenm = 192
		key = string.sub(keyst :: string, 1, 32)
	elseif len == 208 then
		lenm = 160
		key = string.sub(keyst :: string, 1, 24)
	elseif len == 176 then
		lenm = 128
		key = string.sub(keyst :: string, 1, 16)
	else
		error("Round keys must be either 240, 208 or 128 bytes long")
	end

	local keym: buffer? = roundKeys
	local mode: any = mode or modes.ECB
	local fwd = mode.FwdMode; local inv = mode.InvMode; local segm = mode.SegmentSize or 16
	local pad: any = pad or pads.Pkcs7
	local pd = pad.Pad; local upd = pad.Unpad
	local cipher = newproxy(true) :: AesCipher 
	local meta = getmetatable(cipher) 

	local function encp(plaintext, offset, output, offsetOut)
		encryptBlock(keym :: buffer, lenm :: number, plaintext, offset, output, offsetOut)
	end
	local function decp(ciphertext, offset, output, offsetOut)
		decryptBlock(keym :: buffer, lenm :: number, ciphertext, offset, output, offsetOut)
	end
	local function enc(self: AesCipher, plaintext, output, ...)
		local raw = typeof(plaintext)
		local text = if raw == "buffer" then plaintext :: buffer elseif raw == "string" then buffer.fromstring(plaintext)
			else error(`Unable to cast {raw} to buffer`) 
		output = typeof(output) == "buffer" and output
		if self ~= cipher then 
			return self:Encrypt(text, output :: buffer, ...)
		elseif lenm then
			local out = pd(text, output, segm)
			fwd(encp, decp, if pad.Overwrite == false then text else out, out, mode, ...)
			return out
		else
			error("AesCipher object's already destroyed")
			return buffer.create(0) 
		end
	end
	local function encb(self: AesCipher, plaintext, offset, output, offsetOut)
		if self ~= cipher then
			self:EncryptBlock(plaintext, offset, output, offsetOut)
		elseif lenm then
			encryptBlock(keym :: buffer, lenm :: number, plaintext, offset, output or plaintext, offsetOut or offset)
		else
			error("AesCipher object's already destroyed")
		end
	end
	local function dec(self: AesCipher, ciphertext, output, ...)
		local raw = typeof(ciphertext)
		local ciph = if raw == "buffer" then ciphertext :: buffer elseif raw == "string" then buffer.fromstring(ciphertext)
			else error(`Unable to cast {raw} to buffer`)
		output = typeof(output) == "buffer" and output
		if self ~= cipher then
			return self:Decrypt(ciph, output :: buffer, ...)
		elseif lenm then
			local ovw = pad.Overwrite
			local text = if ovw == nil then buffer.create(buffer.len(ciph)) elseif ovw then ciph else output or buffer.create(buffer.len(ciph))
			inv(encp, decp, ciph, text, mode, ...)
			return upd(text, output, segm)
		else
			error("AesCipher object's already destroyed")
			return buffer.create(0)
		end
	end
	local function decb(self: AesCipher, ciphertext, offset, output, offsetOut)
		if self ~= cipher then
			self:DecryptBlock(ciphertext, offset, output, offsetOut)
		elseif lenm then
			decryptBlock(keym :: buffer, lenm :: number, ciphertext, offset, output or ciphertext, offsetOut or offset)
		else
			error("AesCipher object's already destroyed")
		end
	end
	local function destroy(self: AesCipher): ()
		if self ~= cipher then
			self:Destroy()
		elseif lenm then
			keyst, keym, lenm, fwd, inv, mode, pad, key, len = nil, nil, nil, nil, nil, nil, nil, nil, nil
		else
			error("AesCipher object's already destroyed")
		end
	end

	meta.__index = function(_, idx)
		return if idx == "Encrypt" then enc elseif idx == "Decrypt" then dec elseif idx == "EncryptBlock" then encb elseif idx == "DecryptBlock" then decb
			elseif idx == "Destroy" then destroy elseif lenm then (if idx == "Key" then key elseif idx == "RoundKeys" then keyst
				elseif idx == "Mode" then mode elseif idx == "Padding" then pad elseif idx == "Length" then len
				else error(`{idx} is not a valid member of AesCipher`)) else error("AesCipher object's already destroyed")
	end
	meta.__newindex = newidx
	meta.__tostring = tostr
	meta.__len = function(): number
		return len or error("AesCipher object's destroyed")
	end
	meta.__metatable = "AesCipher object: Metatable's locked"
	return cipher
end

return table.freeze({
	new = function(masterKey, mode, pad) 
		return fromKey(expandKey(masterKey), mode, pad)
	end,
	expandKey = expandKey,
	fromKey = fromKey,
	modes = modes, 
	pads = pads 
})
