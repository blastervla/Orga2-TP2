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
pyenv virtualenv 3.6.5 tp3
```

En el directorio del proyecto

```
pyenv activate tp3
```

### Directamente con python3
```
python3 -m venv tp3
source tp3/bin/activate
```

### Con Conda
```
conda create --name tp3 python=3.6.5
conda activate tp3
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
Ejecutar la primera celda del notebook `TP3.ipynb` o seguir los siguientes pasos o compilar el código C y asm a mano y pasar el ejecutable tp2 de src/build a exp.

## Correr el código
Dentro de cada celda podemos hacer nuestros tests en python, y para correr un filtro debemos hacerlo de la siguiente manera:

```

```