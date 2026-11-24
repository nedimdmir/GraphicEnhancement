"""An empty owned window for actual Windows foreground/occlusion testing."""
import tkinter as tk
root=tk.Tk()
root.title('GraphicEnhancement background playback test')
root.geometry('320x140+40+40')
tk.Label(root,text='GraphicEnhancement focus-loss test window\nOwned test; no user settings changed',padx=12,pady=28).pack()
root.after(270000,root.destroy)
root.mainloop()
