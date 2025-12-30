NAME="zz"

run:
	zig build
	@$(MAKE) install

debug:
	zig build run 2>&1 | less

prod:
	zig build -Doptimize=ReleaseFast
	@$(MAKE) install

install:
	mkdir -p ~/bin
	rm -f ~/bin/$(NAME)
	mv ./zig-out/bin/$(NAME) ~/bin/$(NAME)
