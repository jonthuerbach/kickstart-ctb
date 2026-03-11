local FormatNumber = require(script.Parent.Parent.Libraries.FormatNumber.Main)

local NumberFormatter = {}

local abbreviations = FormatNumber.Notation.compactWithSuffixThousands({
	"K",
	"M",
	"B",
	"T",
	"Qa",
	"Qb",
	"Qc",
	"Qd",
	"Qe",
	"Qf",
	"Qg",
	"Qh",
	"Qi",
	"Qj",
	"Qk",
	"Ql",
	"Qm",
	"Qn",
	"Qo",
	"Qp",
	"Qq",
	"Qr",
	"Qs",
	"Qt",
	"Qu",
	"Qv",
	"Qw",
	"Qx",
	"Qy",
	"Qz",
})

local compactFormatter = FormatNumber
	.NumberFormatter
	.with()
	:Notation(abbreviations)
	:Precision(FormatNumber.Precision.integer():WithMinDigits(3))

function NumberFormatter.FormatCompact(value: number): string
	return compactFormatter:Format(value)
end

function NumberFormatter.FormatMoney(value: number): string
	local sign = value < 0 and "-" or ""
	local absoluteValue = math.abs(value)
	return sign .. "$" .. compactFormatter:Format(absoluteValue)
end

return NumberFormatter
