# TP2

## Creación de un entorno virtual de python

### Con pyenv

```
curl https://pyenv.run | bash
```

Luego, se sugiere agregar unas líneas al bashrc. Hacer eso, **REINICIAR LA CONSOLA** y luego...

```
pyenv install 3.6.5
pyenv global 3.6.5
pyenv virtualenv 3.6.5 tp2
```

En el directorio del proyecto

```
pyenv activate tp2
```

### Directamente con python3
```
python3 -m venv venv 
source venv/bin/activate
```

### Con Conda
```
conda create --name tp2 python=3.6.5
conda activate tp2
```

## Instalación de las depencias
```
pip install -r requirements.txt
```

## Correr notebooks de jupyter

```
cd notebooks
jupyter lab
```
o  notebook
```
jupyter notebook
```


## Compilación
Se sugiere tener un notebook distinto por filtro para evitar problemas de mergeo con git.

Ejecutar la primera celda del notebook correspondiente al filtro que se quiere testear `.ipynb` o seguir los siguientes pasos o compilar el código C y asm a mano y copiar el ejecutable tp2 de src/build a exp.

## Correr el código
Dentro de cada celda podemos hacer nuestros tests en python, y para correr un filtro debemos hacerlo de la siguiente manera:

```
call([\"./tp2\", \"args\", \"to\", \"spa\"])
```

Por ejemplo:
```
call([\"./tp2\", \"Nivel\", \"-i\", \"asm\", \"img/Puente.bmp\", \"7\"])
```

Hay más información dentro del notebook, sugiero correr las primeras celdas y leer los outputs.
