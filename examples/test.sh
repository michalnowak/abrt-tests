for f in *.test; do
        b="${f%%.test}"
        abrt-dump-oops -o "$f" >"$b".out 2>&1
        if diff -u "$b".right "$b".out >"$b".diff 2>&1; then
                rm "$b".out "$b".diff
        fi
done
