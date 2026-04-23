extends RichTextLabel

func _on_meta_clicked(meta):
    # 'meta' contains the data from the [url=...] tag
    OS.shell_open(str(meta)) # Opens in the user's default browser
