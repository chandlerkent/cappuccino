// sprintf:

var formatRegex = new RegExp("([^%]+|%[\\+\\-\\ \\#0]*[0-9\\*]*(.[0-9\\*]+)?[hlL]?[cbBdieEfgGosuxXpn%@])", "g");
var tagRegex = new RegExp("(%)([\\+\\-\\ \\#0]*)([0-9\\*]*)((.[0-9\\*]+)?)([hlL]?)([cbBdieEfgGosuxXpn%@])");

exports.sprintf = function(format)
{
    var format = arguments[0],
        tokens = format.match(formatRegex),
        index = 0,
        result = "",
        arg = 1;

    for (var i = 0; i < tokens.length; i++)
    {
        var t = tokens[i];
        if (format.substring(index, index + t.length) != t)
        {
            return result;
        }
        index += t.length;

        if (t.charAt(0) != "%")
        {
            result += t;
        }
        else
        {
            var subtokens = t.match(tagRegex);
            if (subtokens.length != 8 || subtokens[0] != t)
            {
                return result;
            }

            var percentSign     = subtokens[1],
                flags           = subtokens[2],
                widthString     = subtokens[3],
                precisionString = subtokens[4],
                length          = subtokens[6],
                specifier       = subtokens[7];

            var width = null;
            if (widthString == "*")
                width = arguments[arg++];
            else if (widthString != "")
                width = Number(widthString);

            var precision = null;
            if (precisionString == ".*")
                precision = arguments[arg++];
            else if (precisionString != "")
                precision = Number(precisionString.substring(1));

            var leftJustify = (flags.indexOf("-") >= 0);
            var padZeros    = (flags.indexOf("0") >= 0);

            var subresult = "";

            if (RegExp("[bBdiufeExXo]").test(specifier))
            {
                var num = Number(arguments[arg++]);

                var sign = "";
                if (num < 0)
                {
                    sign = "-";
                }
                else
                {
                    if (flags.indexOf("+") >= 0)
                        sign = "+";
                    else if (flags.indexOf(" ") >= 0)
                        sign = " ";
                }

                if (specifier == "d" || specifier == "i" || specifier == "u")
                {
                    var number = String(Math.abs(Math.floor(num)));

                    subresult = justify(sign, "", number, "", width, leftJustify, padZeros)
                }

                if (specifier == "f")
                {
                    var number = String((precision != null) ? Math.abs(num).toFixed(precision) : Math.abs(num));
                    var suffix = (flags.indexOf("#") >= 0 && number.indexOf(".") < 0) ? "." : "";

                    subresult = justify(sign, "", number, suffix, width, leftJustify, padZeros);
                }

                if (specifier == "e" || specifier == "E")
                {
                    var number = String(Math.abs(num).toExponential(precision != null ? precision : 21));
                    var suffix = (flags.indexOf("#") >= 0 && number.indexOf(".") < 0) ? "." : "";

                    subresult = justify(sign, "", number, suffix, width, leftJustify, padZeros);
                }

                if (specifier == "x" || specifier == "X")
                {
                    var number = String(Math.abs(num).toString(16));
                    var prefix = (flags.indexOf("#") >= 0 && num != 0) ? "0x" : "";

                    subresult = justify(sign, prefix, number, "", width, leftJustify, padZeros);
                }

                if (specifier == "b" || specifier == "B")
                {
                    var number = String(Math.abs(num).toString(2));
                    var prefix = (flags.indexOf("#") >= 0 && num != 0) ? "0b" : "";

                    subresult = justify(sign, prefix, number, "", width, leftJustify, padZeros);
                }

                if (specifier == "o")
                {
                    var number = String(Math.abs(num).toString(8));
                    var prefix = (flags.indexOf("#") >= 0 && num != 0) ? "0" : "";

                    subresult = justify(sign, prefix, number, "", width, leftJustify, padZeros);
                }

                if (RegExp("[A-Z]").test(specifier))
                    subresult = subresult.toUpperCase();
                else
                    subresult = subresult.toLowerCase();
            }
            else
            {
                var subresult = "";

                if (specifier == "%")
                    subresult = "%";
                else if (specifier == "c")
                    subresult = String(arguments[arg++]).charAt(0);
                else if (specifier == "s" || specifier == "@")
                    subresult = String(arguments[arg++]);
                else if (specifier == "p" || specifier == "n")
                {
                    arg++;
                    subresult = "";
                }

                subresult = justify("", "", subresult, "", width, leftJustify, false);
            }

            result += subresult;
        }
    }
    return result;
}

function justify(sign, prefix, string, suffix, width, leftJustify, padZeros)
{
    var length = (sign.length + prefix.length + string.length + suffix.length);
    if (leftJustify)
    {
        return sign + prefix + string + suffix + pad(width - length, " ");
    }
    else
    {
        if (padZeros)
            return sign + prefix + pad(width - length, "0") + string + suffix;
        else
            return pad(width - length, " ") + sign + prefix + string + suffix;
    }
}

function pad(n, ch)
{
    return Array(MAX(0,n)+1).join(ch);
}
