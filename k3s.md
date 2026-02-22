# Tutoriel de déploiement avec k3s
<img src="https://upload.wikimedia.org/wikipedia/commons/2/2a/Ets_quebec_logo.png" width="250">    
ÉTS - LOG430 - Architecture logicielle - Chargé de laboratoire: Gabriel C. Ullmann, Hiver 2026.

Dans ce tutoriel, vous allez utiliser Kubernetes (k8s), un orchestrateur de contenuer pour créer une grappe avec 2 serveurs et déployer l'application de votre environement dev à votre environement production de manière semi automatique, en pouvant repliquer votre application et ajouter plusieur noueds à la grappe de maniere simple.

## 🎯 Objectifs d'apprentissage
- Apprendre à utiliser un orchestrateur de conteneurs ([k3s](https://k3s.io/), une version simplifié de [Kubernetes](https://github.com/kubernetes/kubernetes))
- Apprendre à utiliser [Docker Hub](https://hub.docker.com/repository/docker/nkinesis/store-manager/general) pour hebergér vos images Docker
- Comprendre les avantages d'utiliser un orchestrateur de conteneur par rapport à simplement utiliser les conteneurs Docker

## 💻 Exigences du projet
Vous aurez besoin de:
- 🏠 Votre ordinateur (votre environement de developpement, le nœud **worker**) content le code de ce depot
- ☁️ 1 VM distante avec IP fixé (votre environement de production, le nœud **master**)
- Un compte Docker (vous pouver créer une gratuitement dans le site web)

Pour facilier la comprehension des instructions, l'environement developpement sera simbolisé par un emoji maison 🏠 et la VM sera simbolisé par un emoji nuage ☁️.

## ❓ Questions fréquentes

### Pourquoi ne pas configurer plutot le nœud master dans mon environement de developpement? 
Pour simplifier la configuration réseau, c'est mieux si le noeud master a l'IP fixé. Les workers peuvent avoir n'importe quel address IP, et il peu changer à n'importe quel moment sans impact dans notre configuration parce que chaque fois que l'IP change, le worker reconnectera au master. Comme la majorité des gens n'a pas un IP fixe dans son connexion d'internet chez eux, nous recommendes ce setup là. Cependant, si vous avez un IP fixé, vous pouvez créer le noeud master dans votre ordinateur.   

### J'ai vu d'autres tutoriels de Kubernetes et c'est different. Quel est la manière correcte de le faire?
Il y a pluseiurs differentes manières d'installer Kubernetes, et ça va changer en fonction de ton configuration réseau, nombre de serveurs dans la grappe, technologie de conteneurs utilisé, etc. Ici nous avons chosi k3s parce que c'est une solution simple et rapide pour créer une petite grappe de serveurs que sert des applications contenuerisés avec Docker (comme Store Manager, par example). 

## ⚙️ Setup

### 1. Configurez le nœud master ☁️

Installez k3s :
```bash
curl -sfL https://get.k3s.io | sh -
```

Vérifiez que le nœud est prêt :
```bash
kubectl get nodes
```

Voici le résultat attendu:
```bash
NAME              STATUS   ROLES           
log430-votre-vm   Ready    control-plane  
```

Affichez le jeton pour connecter des nœuds supplémentaires et copiez-le :
```bash
cat /var/lib/rancher/k3s/server/node-token
```

Affichez le fichier de configuration et copiez-le :
```bash
cat /etc/rancher/k3s/k3s.yaml
```

### 2. Configurez l'accès depuis votre machine de développement 🏠

Indiquez le bon addresse IP de votre VM (`<ip-vm>`) et jeton (`<token>`):
```bash
curl -sfL https://get.k3s.io | K3S_URL=https://<ip-vm>:6443 K3S_TOKEN=<token> sh -
```

> ⚠️ **ATTENTION** : Si votre machine de développement utilise une architecture ARM (Apple Silicon), vous devez d'abord installer k3d (`brew install k3d`). En lieu d'installer k3s directement dans le système d'exploitation, ça exécutera k3s dans un conteneur Docker qui créer une couche de compatibilité entre l'image k3d amd64 et le système arm64.

Sur votre machine de développement, créez le fichier kubeconfig. Collez le contenu copié depuis le fichier `k3s.yaml` dans la VM:
```bash
mkdir -p ~/.kube
nano ~/.kube/config
```

Dans le fichier, remplacez `<remote-server-ip>` par l'IP fixe de la VM :
```yaml
server: https://<remote-server-ip>:6443
```

Vérifiez la connexion :
```bash
kubectl get nodes
```

Si tout est bien configuré, vous devriez voir le node master sur la liste.

### 3. Publiez votre image sur Docker Hub 🏠

Docker Hub offre un nombre illimité de dépôts publics, ou jusqu'à 1 dépôt privé gratuit. Ici, nous vous recommendons d'utiliser un dépot public. Ouvrez une nouvelle fenetre terminal dans le fichier du projet `log430-labo5`, exécutez `docker login` et suivez les instructions pour authentifier dans votre navigateur.

```bash
docker login
```

Ensuite, utilisez votre nom d'utilisateur pour créer et televerser une nouvelle image. Remplacez `<nom-app>` par `store-manager`.
```bash
docker build -t <nom-utilisateur>/<nom-app>:latest .
docker push <nom-utilisateur>/<nom-app>:latest
```

> 📝 **NOTE** : Si votre machine de développement utilise une architecture ARM (Apple Silicon), vous devez construire une image multi-plateforme pour qu'elle fonctionne sur une VM ou serveur AMD64 :
```bash
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 -t <votre-utilisateur>/<nom-app>:latest --push .
```

Remplacez le nom de l'image dans le manifeste Kubernetes dans ce dépôt (`k8s-manifests.yml`) par le vôtre. Si vous voulez, vous pouvez garder l'image default (`nkinesis/store-manager:latest`), cependant vous ne pourrez pas changer le code dans l'image parce que ce n'est pas dans votre compte.

### 4. Créez les ConfigMaps 🏠

Les fichiers de configuration (KrakenD, base de données) doivent être chargés en tant que ConfigMaps avant de déployer :

```bash
kubectl create configmap krakend-config --from-file=krakend.json=./config/krakend.json
kubectl create configmap db-init --from-file=./db-init/
```

Déployez!

```bash
kubectl apply -f k8s-manifests.yml
```

### 5. Vérifiez le déploiement dans la VM ☁️


Surveillez le démarrage des pods :
```bash
kubectl get pods -w
```

Voici le résultat attendu:
```bash
NAME                             READY   STATUS    RESTARTS      
api-gateway-786b9dffdb-hkx2t     1/1     Running   1 (1m ago)    
mysql-5647796678-4cnws           1/1     Running   1 (1m ago)    
redis-67555ffc9b-xgtxb           1/1     Running   1 (1m ago)   
store-manager-7f675d8f65-xjc2v   1/1     Running   1 (1m ago) 
```

> 📝 **NOTE** : Un **pod** consiste en un ou plusieurs conteneurs qui ont la garantie d'être co-localisés sur une machine et peuvent en partager les ressources de calcul.

Affichez les services et leurs ports :
```bash
kubectl get services
```

Voici le résultat attendu:
```bash
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          
api-gateway     NodePort    10.43.5.109     <none>        8080:31628/TCP   
kubernetes      ClusterIP   10.43.0.1       <none>        443/TCP          
mysql           ClusterIP   10.43.198.200   <none>        3306/TCP         
redis           ClusterIP   10.43.61.252    <none>        6379/TCP         
store-manager   NodePort    10.43.35.136    <none>        5000:32080/TCP   
```

Les services de type `NodePort` sont accessibles depuis l'extérieur via `http://<remote-server-ip>:<port>`. Par exemple, pour connecter à Store Manager directement, utilisez Postman pour envoyer une requête à `http://<remote-server-ip>:32080`. Le port `32080` est selectioné de manière aléatoire par k3s.


> ⚠️ **ATTENTION** : N'utilisez jamais les IP dans la colonne `CLUSTER-IP`. Ce sont les IPs internes dans les conteneurs. Pour la communication externe, utilisez l'IP que vous avez defini pour votre VM.

> 📝 **NOTE** : Dans ce tutoriel, les services `store-manager` et `api-gateway` ont des ports ouverts à l'exterieur pour faciliter la debogage et experimentation. Dans un environnement de production normalement seulment l'API gateway serait ouvert à l'exterieur.

### 6. Mettez à jour l'application 🏠

À chaque fois qui vous changez le code et veux redeploier, reconstruissez et poussez l'image à Docker Hub, puis redémarrer le déploiement :

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t <votre-utilisateur>/<nom-app>:latest --push .
kubectl rollout restart deployment store-manager
```

### 7. Ajoutez un nouveau noeud (optionnel)
Pour ajouter d'autres nodes dans la grappe, repetez l'étape 2.

### 8. Changez le nombre de replicas (optionnel)
Changez l'attribut `replicas` dans `k8s-manifests.yml`. Ici nous utilison la valeur default `replicas: 1`. Alternativement:

```bash
kubectl scale deployment store-manager --replicas=3
```