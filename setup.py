from setuptools import setup, find_packages, find_namespace_packages

setup(
    name='jutlandia_site',
    packages=['jutlandia_site'],
    version="1.0",
    include_package_data=True,
    entry_points={
        'console_scripts': [
            "jutlandia = jutlandia_site:main"
        ]
    },
    install_requires=[
        'flask',
        "requests",
        "flask_sqlalchemy"
    ],
)
