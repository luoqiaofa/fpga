// https://blog.csdn.net/w40306030072/article/details/79014822
function integer clogb2 (input integer bit_depth);
begin
    for(clogb2=0; bit_depth > 0; clogb2=clogb2+1)
        bit_depth = bit_depth >> 1;
end
endfunction
