# Tutoriel de déploiement avec k3s
<img src="https://upload.wikimedia.org/wikipedia/commons/2/2a/Ets_quebec_logo.png" width="250">    
ÉTS - LOG430 - Architecture logicielle - Chargé de laboratoire : Gabriel C. Ullmann, Hiver 2026.

Dans ce tutoriel, vous allez utiliser [Kubernetes](https://github.com/kubernetes/kubernetes), un orchestrateur de conteneurs, pour créer une grappe avec 2 serveurs et déployer l'application de votre environnement de développement à votre environnement de production de manière semi-automatique, en pouvant répliquer votre application et ajouter plusieurs nœuds à la grappe de manière simple.

## 🎯 Objectifs d'apprentissage
- Apprendre à utiliser [k3s](https://k3s.io/), une version simplifiée de Kubernetes
- Apprendre à utiliser [Docker Hub](https://hub.docker.com/repository/docker/nkinesis/store-manager/general) pour héberger vos images Docker
- Se familiariser avec la terminologie des grappes de serveurs (master, worker, node, pod, service)
- Comprendre les avantages d'utiliser un orchestrateur de conteneurs par rapport à simplement utiliser les conteneurs Docker

## 💻 Exigences du projet
Vous aurez besoin de :
- 🏠 Votre ordinateur (votre environnement de développement, le nœud **worker**) contenant le code de ce dépôt avec des implémentations recommendés dans le README
- ☁️ 1 VM distante avec IP fixe (votre environnement de production, le nœud **master**)
- Un compte Docker (vous pouvez en créer un gratuitement sur le site web)

Pour faciliter la compréhension des instructions, votre environnement de développement sera symbolisé par un emoji maison 🏠 et votre VM ou serveur distant sera symbolisée par un emoji nuage ☁️.

## ❓ Questions fréquentes

### Pourquoi ne pas configurer plutôt le nœud master dans mon environnement de développement? 
Pour simplifier la configuration réseau, il est préférable que le nœud master ait une IP fixe. Les workers peuvent avoir n'importe quelle adresse IP, et elle peut changer à n'importe quel moment sans impact sur notre configuration, car chaque fois que l'IP change, le worker se reconnecte au master. Comme la majorité des gens n'ont pas d'IP fixe dans leur connexion internet à domicile, nous recommandons cette configuration. Cependant, si vous avez une IP fixe chez vous, vous pouvez créer le nœud master sur votre ordinateur.

### J'ai vu d'autres tutoriels de Kubernetes et c'est différent. Quelle est la bonne manière de le faire ?
Il existe plusieurs façons différentes d'installer Kubernetes, et cela variera en fonction de votre configuration réseau, du nombre de serveurs dans la grappe, de la technologie de conteneurs utilisée, etc. Ici, nous avons choisi `k3s` parce que c'est une solution simple et rapide pour créer une petite grappe de serveurs qui sert des applications conteneurisées avec Docker (comme Store Manager, par exemple).

### Pourquoi mon nœud k3s ne démarre-t-il pas ?
Veuillez suivre attentivement les instructions et vérifier si votre serveur dispose de ressources de calcul suffisantes (RAM, CPU et stockage). 2 Go de RAM devraient suffire pour ce tutoriel. Si nécessaire, arrêtez ou supprimez les autres conteneurs présents sur votre serveur afin d'économiser des ressources.

## ⚙️ Setup

### 1. Configurez le nœud master ☁️

Installez `k3s` :
```bash
curl -sfL https://get.k3s.io | sh -
```

Vérifiez que le nœud est prêt :
```bash
kubectl get nodes
```

Voici le résultat attendu :
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

Indiquez la bonne adresse IP de votre VM (`<ip-vm>`) et le jeton (`<token>`) :
```bash
curl -sfL https://get.k3s.io | K3S_URL=https://<ip-vm>:6443 K3S_TOKEN=<token> sh -
```

> 📝 **NOTE** : Si votre machine de développement utilise une architecture ARM (Apple Silicon), vous devez d'abord installer `k3d` (`brew install k3d`). Au lieu d'installer `k3s` directement dans le système d'exploitation, cela exécutera `k3s` dans un conteneur Docker qui crée une couche de compatibilité entre l'image `k3d` amd64 et votre système arm64.

Sur votre machine de développement, créez le fichier `kubeconfig`. Dans ce fichier, collez le contenu copié depuis le fichier `k3s.yaml` pendant l'étape précédante :
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

Si tout est bien configuré, vous devriez voir le nœud master dans la liste de nœuds.

### 3. Publiez votre image sur Docker Hub 🏠

Docker Hub offre un nombre illimité de dépôts publics, ou jusqu'à 1 dépôt privé gratuit. Ici, nous vous recommandons d'utiliser un dépôt public. Ouvrez une nouvelle fenêtre de terminal dans le répertoire du projet `log430-labo5`, exécutez `docker login` et suivez les instructions pour vous authentifier dans votre navigateur.

```bash
docker login
```

Ensuite, utilisez votre nom d'utilisateur pour créer et téléverser une nouvelle image. Remplacez `<nom-app>` par `store-manager`.
```bash
docker build -t <nom-utilisateur>/<nom-app>:latest .
docker push <nom-utilisateur>/<nom-app>:latest
```

> 📝 **NOTE** : Si votre machine de développement utilise une architecture ARM (Apple Silicon), vous devez construire une image multi-plateforme pour qu'elle fonctionne sur une VM ou un serveur AMD64 :
```bash
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 -t <votre-utilisateur>/<nom-app>:latest --push .
```

Remplacez le nom de l'image dans le manifeste Kubernetes de ce dépôt (`k8s-manifests.yml`) par le vôtre. Si vous le souhaitez, vous pouvez conserver l'image par défaut (`nkinesis/store-manager:latest`), mais vous ne pourrez pas modifier le code de l'image puisqu'elle n'est pas dans votre compte.

### 4. Créez les ConfigMaps 🏠

Les fichiers de configuration (KrakenD, base de données) doivent être chargés en tant que ConfigMaps avant de déployer :

```bash
kubectl create configmap krakend-config --from-file=krakend.json=./config/krakend.json
kubectl create configmap db-init --from-file=./db-init/
```

Déployez !

```bash
kubectl apply -f k8s-manifests.yml
```

### 5. Vérifiez le déploiement dans la VM ☁️


Surveillez le démarrage des pods :
```bash
kubectl get pods -w
```

Voici le résultat attendu :
```bash
NAME                             READY   STATUS    RESTARTS      
api-gateway-786b9dffdb-hkx2t     1/1     Running   1 (1m ago)    
mysql-5647796678-4cnws           1/1     Running   1 (1m ago)    
redis-67555ffc9b-xgtxb           1/1     Running   1 (1m ago)   
store-manager-7f675d8f65-xjc2v   1/1     Running   1 (1m ago) 
```

> 📝 **NOTE** : Un **pod** consiste en un ou plusieurs conteneurs qui ont la garantie d'être co-localisés sur une même machine et peuvent en partager les ressources de calcul.

Affichez les services et leurs ports :
```bash
kubectl get services
```

Voici le résultat attendu :
```bash
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          
api-gateway     NodePort    10.43.5.109     <none>        8080:31628/TCP   
kubernetes      ClusterIP   10.43.0.1       <none>        443/TCP          
mysql           ClusterIP   10.43.198.200   <none>        3306/TCP         
redis           ClusterIP   10.43.61.252    <none>        6379/TCP         
store-manager   NodePort    10.43.35.136    <none>        5000:32080/TCP   
```

Les services de type `NodePort` sont accessibles depuis l'extérieur via `http://<remote-server-ip>:<port>`. Par exemple, pour se connecter à Store Manager directement, utilisez Postman pour envoyer une requête à `http://<remote-server-ip>:32080`. Le port `32080` est sélectionné de manière aléatoire par k3s.


> ⚠️ **ATTENTION** : N'utilisez jamais les IP dans la colonne `CLUSTER-IP`. Ce sont les IP internes des conteneurs. Pour la communication externe, utilisez l'IP que vous avez définie pour votre VM.

> 📝 **NOTE** : Dans ce tutoriel, les services `store-manager` et `api-gateway` ont des ports ouverts vers l'extérieur pour faciliter le débogage et l'expérimentation. Dans un environnement de production, normalement seule l'API Gateway serait ouverte vers l'extérieur.

### 6. Mettez à jour l'application 🏠

À chaque fois que vous modifiez le code et souhaitez redéployer, reconstruisez et poussez l'image vers Docker Hub, puis redémarrez le déploiement :

```bash
docker build -t <nom-utilisateur>/<nom-app>:latest .
docker push <nom-utilisateur>/<nom-app>:latest
kubectl rollout restart deployment store-manager
```

### 7. Ajoutez un nouveau nœud (optionnel)
Pour ajouter d'autres nœuds à la grappe (ex. une autre VM), répétez l'étape 2.

### 8. Changez le nombre de réplicas (optionnel)
Modifiez l'attribut `replicas` dans `k8s-manifests.yml`. Ici, nous utilisons la valeur par défaut `replicas: 1`. Alternativement :

```bash
kubectl scale deployment store-manager --replicas=3
```