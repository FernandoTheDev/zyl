def mandelbrot(x0, y0, max_iter):
    x = 0.0
    y = 0.0
    iteration = 0
    
    while iteration < max_iter:
        x2 = x * x
        y2 = y * y
        
        if x2 + y2 > 4.0:
            return iteration
        
        xtemp = x2 - y2 + x0
        y = 2.0 * x * y + y0
        x = xtemp
        
        iteration += 1
    
    return max_iter

def render(width, height, max_iter):
    xmin = -2.5
    xmax = 1.0
    ymin = -1.0
    ymax = 1.0
    
    for row in range(height):
        for col in range(width):
            x0 = xmin + (xmax - xmin) * col / width
            y0 = ymin + (ymax - ymin) * row / height
            
            iter = mandelbrot(x0, y0, max_iter)
            
            if iter == max_iter:
                print("*", end="")
            elif iter > max_iter // 2:
                print("+", end="")
            elif iter > max_iter // 4:
                print(".", end="")
            else:
                print(" ", end="")
        print()

render(1000, 1000, 1000)
